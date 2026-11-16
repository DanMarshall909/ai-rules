#!/usr/bin/env python3
"""Observable CLI contracts for the portable project handoff command."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import time
import unittest

REPO = Path(__file__).resolve().parent.parent
SCRIPT = Path(os.environ.get('AI_HANDOFF_SCRIPT', REPO / 'skills/session-handoff/scripts/ai-handoff.sh'))
BASH = os.environ.get('AI_HANDOFF_BASH', shutil.which('bash') or 'bash')


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='handoff-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / 'project with café'
        self.project.mkdir()
        self.environment = os.environ.copy()
        for name in ('CODEX_THREAD_ID', 'CODEX_SESSION_ID', 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR'):
            self.environment.pop(name, None)
        self.git('init', '-q')
        self.state = self.project / '.git/handoff'

    def git(self, *arguments, cwd=None):
        return subprocess.check_output(['git', '-C', str(cwd or self.project), *arguments],
                                       env=self.environment, stderr=subprocess.PIPE, text=True).strip()

    def invoke(self, *arguments, cwd=None, environment=None):
        return subprocess.run([BASH, str(SCRIPT), *arguments], cwd=cwd or self.project,
                              env=environment or self.environment, capture_output=True, timeout=15)

    def expect(self, result, code, diagnostic=None):
        self.assertEqual(code, result.returncode, result.stderr.decode(errors='replace'))
        if diagnostic:
            self.assertIn(diagnostic.encode(), result.stderr)

    def create(self, data=b'# Current\n', expected='none', *, owner='test:root', environment=None):
        prepared = self.root / 'prepared.md'
        prepared.write_bytes(data)
        arguments = ['new', '--expect', expected, '--from', str(prepared)]
        if owner:
            arguments += ['--owner', owner]
        return self.invoke(*arguments, environment=environment)

    def revision(self):
        result = self.invoke('latest')
        self.expect(result, 0)
        return result.stdout.split(b'Revision: ', 1)[1].split(b'\n', 1)[0].decode()

    def test_rotation_archives_exact_previous_bytes_and_lists_newest_first(self):
        first = b'# First\n\nUseful recovery context.\n\n'
        second = b'# Second\nChanged facts.\n'
        third = b'# Third\n'
        self.expect(self.create(first), 0)
        self.expect(self.create(second, self.revision()), 0)
        self.expect(self.create(third, self.revision()), 0)
        self.assertEqual(third, (self.state / 'HANDOFF.md').read_bytes())
        archives = sorted((self.state / 'archive').iterdir())
        self.assertEqual([first, second], [path.read_bytes() for path in archives])
        result = self.invoke('list'); self.expect(result, 0)
        rows = result.stdout.decode().splitlines()
        self.assertTrue(rows[0].startswith('current\t'))
        self.assertEqual([str(path) for path in reversed(archives)],
                         [row.split('\t', 1)[1] for row in rows[1:]])
        self.assertEqual({'HANDOFF.md', 'archive'}, {path.name for path in self.state.iterdir()})

    def test_stale_writer_and_existing_lock_preserve_current_and_archives(self):
        self.expect(self.create(), 0)
        old = self.revision()
        self.expect(self.create(b'# Newer\n', old), 0)
        current = (self.state / 'HANDOFF.md').read_bytes()
        archives = list((self.state / 'archive').iterdir())
        self.expect(self.create(b'# Stale\n', old), 5, 'revision mismatch')
        self.assertEqual(current, (self.state / 'HANDOFF.md').read_bytes())
        self.assertEqual(archives, list((self.state / 'archive').iterdir()))
        lock = self.state / 'lock'; lock.mkdir()
        (lock / 'owner').write_text('another-session\n')
        self.expect(self.create(b'# Refused\n', self.revision()), 4, 'lock held')
        self.assertEqual('another-session\n', (lock / 'owner').read_text())
        self.assertEqual(current, (self.state / 'HANDOFF.md').read_bytes())

    def test_invalid_prepared_input_and_unknown_owner_preserve_current(self):
        self.expect(self.create(), 0)
        revision = self.revision()
        for data in (b'', b' \n\t\r\n', b'bad\x00input'):
            with self.subTest(data=data):
                self.expect(self.create(data, revision), 2, 'prepared handoff')
        self.expect(self.invoke('new', '--expect', revision, '--from', str(self.root / 'missing'),
                                '--owner', 'test:root'), 2, 'prepared handoff')
        self.expect(self.create(expected=revision, owner=''), 7, 'root owner')
        self.assertEqual(b'# Current\n', (self.state / 'HANDOFF.md').read_bytes())
        self.assertEqual([], list((self.state / 'archive').iterdir()))

    def test_linked_worktrees_share_current_and_unrelated_projects_do_not(self):
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('-c', 'core.hooksPath=/dev/null', 'commit', '--allow-empty', '-qm', 'initial')
        linked = self.root / 'linked tree'
        self.git('worktree', 'add', '-qb', 'linked', str(linked))
        self.expect(self.create(b'# Shared\n'), 0)
        main = self.invoke('latest'); other = self.invoke('latest', cwd=linked)
        self.expect(other, 0); self.assertEqual(main.stdout, other.stdout)
        unrelated = self.root / 'separate'; unrelated.mkdir()
        self.git('init', '-q', cwd=unrelated)
        self.expect(self.invoke('latest', cwd=unrelated), 3)

    def test_operational_failures_preserve_current_and_remove_owned_temporary_files(self):
        self.expect(self.create(), 0)
        revision = self.revision()
        for command in ('cat', 'ln', 'mv'):
            with self.subTest(command=command):
                binary = self.root / ('fail-' + command); binary.mkdir()
                stub = binary / command
                stub.write_text('#!/bin/sh\nexit 73\n'); stub.chmod(0o755)
                environment = self.environment.copy()
                environment['PATH'] = str(binary) + os.pathsep + environment['PATH']
                self.expect(self.create(b'# Replacement\n', revision, environment=environment), 1)
                self.assertEqual(b'# Current\n', (self.state / 'HANDOFF.md').read_bytes())
                self.assertEqual({'HANDOFF.md', 'archive'}, {p.name for p in self.state.iterdir()})

    def test_failed_snapshot_copy_never_returns_partial_text_as_success(self):
        self.expect(self.create(), 0)
        binary = self.root / 'failed-reader'; binary.mkdir()
        helper = binary / 'cat'
        helper.write_text('#!/bin/sh\nprintf "partial text\\n"\nexit 73\n'); helper.chmod(0o755)
        environment = self.environment.copy(); environment['PATH'] = str(binary) + os.pathsep + environment['PATH']
        result = self.invoke('latest', environment=environment)
        self.expect(result, 1, 'cannot read current handoff completely')
        self.assertEqual(b'', result.stdout)
        self.assertEqual(b'# Current\n', (self.state / 'HANDOFF.md').read_bytes())

    def test_metadata_distinguishes_root_delegated_forked_and_unknown(self):
        metadata = self.root / 'metadata.json'
        cases = [
            ({'id': 'thread-root', 'parentThreadId': None, 'source': 'vscode'}, 'root', 0),
            ({'id': 'thread-root', 'parentThreadId': 'parent', 'source': 'vscode'}, 'delegated', 6),
            ({'id': 'thread-root', 'parentThreadId': None, 'source': {'subAgent': 'review'}}, 'delegated', 6),
            ({'id': 'thread-root', 'source': {'subAgent': 'review'}}, 'delegated', 6),
            ({'id': 'thread-root', 'parentThreadId': None, 'source': 'cli', 'forkedFromId': 'original'}, 'root', 0),
            ({'id': 'thread-root', 'source': 'cli'}, 'unknown', 7),
            ({'id': 'thread-root', 'parentThreadId': None, 'source': 'unknown'}, 'unknown', 7),
            ({'id': 'another-thread', 'parentThreadId': None, 'source': 'cli'}, 'unknown', 7),
            ({'id': 'thread-root', 'parentThreadId': False, 'source': 'cli'}, 'unknown', 7),
        ]
        for thread, role, status in cases:
            with self.subTest(thread=thread):
                metadata.write_text(json.dumps({'result': {'thread': thread}}))
                result = self.invoke('role', '--metadata', str(metadata), '--thread', 'thread-root')
                self.expect(result, status)
                self.assertEqual(f'{role}\tthread-root\n'.encode(), result.stdout)
        self.assertFalse(self.state.exists())

    def fake_codex(self, thread):
        binary = self.root / 'bin'; binary.mkdir(exist_ok=True)
        config = self.root / 'codex-metadata.json'; config.write_text(json.dumps(thread))
        log = self.root / 'codex-calls.jsonl'
        executable = binary / 'codex'
        executable.write_text(f'''#!{sys.executable}
import json, sys
from pathlib import Path
for line in sys.stdin:
    request = json.loads(line)
    with Path({str(log)!r}).open('a') as stream:
        stream.write(json.dumps(request) + '\\n')
    if request['method'] == 'initialize':
        print(json.dumps({{'id': 0, 'result': {{}}}}), flush=True)
    elif request['method'] == 'thread/read':
        print(json.dumps({{'id': 1, 'result': {{'thread': json.loads(Path({str(config)!r}).read_text())}}}}), flush=True)
        break
''')
        executable.chmod(0o755)
        environment = self.environment.copy()
        environment.update(PATH=str(binary) + os.pathsep + environment['PATH'], CODEX_THREAD_ID='thread-root')
        return environment, log

    def test_codex_writes_require_matching_root_metadata_without_manual_bypass(self):
        for thread, expected in [
            ({'id': 'thread-root', 'parentThreadId': 'parent', 'source': 'cli'}, 6),
            ({'id': 'another-thread', 'parentThreadId': None, 'source': 'cli'}, 7),
            ({'id': 'thread-root', 'parentThreadId': None, 'source': 'cli'}, 0),
        ]:
            with self.subTest(thread=thread):
                environment, log = self.fake_codex(thread)
                result = self.create(environment=environment, owner='thread-root')
                self.expect(result, expected)
                if expected:
                    self.assertFalse(self.state.exists())
                requests = [json.loads(line) for line in log.read_text().splitlines()]
                self.assertTrue(all(r['method'] in ('initialize', 'initialized', 'thread/read') for r in requests))
                reads = [r for r in requests if r['method'] == 'thread/read']
                self.assertEqual('thread-root', reads[-1]['params']['threadId'])

    def test_unknown_role_can_read_and_metadata_files_cannot_authorize_writes(self):
        self.expect(self.create(), 0)
        environment = self.environment.copy(); environment['CODEX_THREAD_ID'] = 'thread-root'
        self.expect(self.invoke('latest', environment=environment), 0)
        metadata = self.root / 'untrusted.json'; metadata.write_text('{}')
        self.expect(self.invoke('new', '--metadata', str(metadata), '--expect', self.revision(),
                                '--from', str(self.root / 'prepared.md'), '--owner', 'thread-root'), 2)
        self.expect(self.invoke('new', '--thread', 'thread-root', '--expect', self.revision(),
                                '--from', str(self.root / 'prepared.md'), environment=environment), 2)

    def test_missing_role_capabilities_and_malformed_metadata_remain_unknown(self):
        empty_bin = self.root / 'empty-bin'; empty_bin.mkdir()
        environment = self.environment.copy(); environment['PATH'] = str(empty_bin)
        result = self.invoke('role', '--thread', 'thread-root', environment=environment)
        self.expect(result, 7, 'requires codex and jq')
        self.assertEqual(b'unknown\tthread-root\n', result.stdout)
        metadata = self.root / 'bad.json'; metadata.write_text('{not JSON')
        result = self.invoke('role', '--metadata', str(metadata), '--thread', 'thread-root')
        self.expect(result, 7)
        self.assertEqual(b'unknown\tthread-root\n', result.stdout)
        self.assertFalse(self.state.exists())

    def test_missing_current_lists_archives_without_promoting_them(self):
        self.expect(self.create(b'# Older\n'), 0)
        self.expect(self.create(b'# Current\n', self.revision()), 0)
        (self.state / 'HANDOFF.md').unlink()
        result = self.invoke('list')
        self.expect(result, 3, 'no current handoff')
        self.assertTrue(result.stdout.startswith(b'archive\t'))
        self.assertNotIn(b'current\t', result.stdout)
        self.expect(self.invoke('latest'), 3)
        self.assertFalse((self.state / 'HANDOFF.md').exists())

    def test_managed_symlinks_and_unexpected_file_types_are_preserved(self):
        self.state.mkdir()
        outside = self.root / 'outside'; outside.write_bytes(b'keep\n')
        current = self.state / 'HANDOFF.md'; current.symlink_to(outside)
        self.expect(self.invoke('latest'), 2, 'unsafe current')
        self.expect(self.create(), 2, 'unsafe current')
        self.assertEqual(b'keep\n', outside.read_bytes())
        current.unlink(); current.mkdir()
        self.expect(self.invoke('latest'), 2, 'unsafe current')
        current.rmdir()
        (self.state / 'archive').write_bytes(b'keep archive conflict\n')
        self.expect(self.create(), 2, 'unsafe state')
        self.assertEqual(b'keep archive conflict\n', (self.state / 'archive').read_bytes())

    def test_explicit_project_ignores_another_repositories_git_environment(self):
        other = self.root / 'other'; other.mkdir()
        self.git('init', '-q', cwd=other)
        self.expect(self.create(), 0)
        environment = self.environment.copy(); environment['GIT_DIR'] = str(other / '.git')
        result = self.invoke('latest', '--project', str(self.project), environment=environment)
        self.expect(result, 0)
        self.assertIn(str(self.state / 'HANDOFF.md').encode(), result.stdout)

    def test_native_concurrent_writer_is_refused_and_reader_sees_complete_old_then_new(self):
        old = b'# Old\n' * 1000; new = b'# New\n' * 1000
        self.expect(self.create(old), 0)
        revision = self.revision()
        binary = self.root / 'bin'; binary.mkdir()
        entered = self.root / 'entered'; release = self.root / 'release'
        wrapper = binary / 'mv'
        wrapper.write_text(f'''#!{sys.executable}
import os, time, sys
from pathlib import Path
Path({str(entered)!r}).touch()
deadline = time.monotonic() + 5
while not Path({str(release)!r}).exists():
    if time.monotonic() > deadline: sys.exit(74)
    time.sleep(0.01)
os.execv({shutil.which('mv')!r}, ['mv', *sys.argv[1:]])
''')
        wrapper.chmod(0o755)
        environment = self.environment.copy(); environment['PATH'] = str(binary) + os.pathsep + environment['PATH']
        prepared = self.root / 'concurrent.md'; prepared.write_bytes(new)
        process = subprocess.Popen([BASH, str(SCRIPT), 'new', '--expect', revision, '--from', str(prepared),
                                    '--owner', 'test:root'], cwd=self.project, env=environment,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 5
            while not entered.exists():
                self.assertIsNone(process.poll(), 'writer exited before controlled replacement')
                self.assertLess(time.monotonic(), deadline, 'writer never reached replacement')
                time.sleep(0.01)
            result = self.invoke('latest'); self.expect(result, 0)
            self.assertEqual(old, result.stdout.split(b'\n\n', 1)[1])
            self.expect(self.create(b'# Competing\n', revision), 4, 'lock held')
            release.touch()
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(0, process.returncode, stderr)
            result = self.invoke('latest'); self.expect(result, 0)
            self.assertEqual(new, result.stdout.split(b'\n\n', 1)[1])
        finally:
            if process.poll() is None:
                process.kill(); process.communicate()

    def test_separate_git_directory_and_non_git_project_write_to_resolved_state(self):
        separate = self.root / 'separate-worktree'; separate.mkdir()
        gitdir = self.root / 'git-storage'
        self.git('init', '-q', '--separate-git-dir', str(gitdir), str(separate))
        prepared = self.root / 'prepared.md'; prepared.write_text('# Separate\n')
        self.expect(self.invoke('new', '--project', str(separate), '--expect', 'none', '--from',
                                str(prepared), '--owner', 'test:root'), 0)
        self.assertEqual('# Separate\n', (gitdir / 'handoff/HANDOFF.md').read_text())
        plain = self.root / 'plain'; plain.mkdir()
        self.expect(self.invoke('new', '--project', str(plain), '--expect', 'none', '--from',
                                str(prepared), '--owner', 'test:root'), 0)
        self.assertEqual('# Separate\n', (plain / '.handoff/HANDOFF.md').read_text())

    def test_native_unresponsive_role_reader_is_bounded_and_stopped(self):
        binary = self.root / 'bin'; binary.mkdir()
        pid_file = self.root / 'reader.pid'
        executable = binary / 'codex'
        executable.write_text(f'#!{sys.executable}\nimport os,time\nfrom pathlib import Path\nPath({str(pid_file)!r}).write_text(str(os.getpid()))\ntime.sleep(30)\n')
        executable.chmod(0o755)
        environment = self.environment.copy()
        environment.update(PATH=str(binary) + os.pathsep + environment['PATH'], CODEX_THREAD_ID='thread-root')
        started = time.monotonic()
        result = self.create(environment=environment, owner='thread-root')
        self.expect(result, 7, 'could not be established')
        self.assertLess(time.monotonic() - started, 10)
        self.assertFalse(self.state.exists())
        with self.assertRaises(ProcessLookupError):
            os.kill(int(pid_file.read_text()), 0)


    def test_missing_handoff_reads_are_explicit_and_do_not_create_state(self):
        for command in ('latest', 'list'):
            with self.subTest(command=command):
                result = self.invoke(command)
                self.expect(result, 3, 'no current handoff')
                self.assertEqual(b'', result.stdout)
                self.assertFalse(self.state.exists())

    def test_latest_returns_revision_and_exact_document_from_one_snapshot(self):
        self.state.mkdir()
        document = b'# Recovery\n\nVerified result.\n\n\n'
        (self.state / 'HANDOFF.md').write_bytes(document)
        result = self.invoke('latest')
        self.expect(result, 0)
        headers, body = result.stdout.split(b'\n\n', 1)
        self.assertIn(str(self.state / 'HANDOFF.md').encode(), headers)
        self.assertRegex(headers, rb'Revision: [0-9]+-[0-9]+')
        self.assertEqual(document, body)

    def test_non_git_requires_explicit_project_and_rejects_symlinked_state(self):
        plain = self.root / 'plain'; plain.mkdir()
        self.expect(self.invoke('latest', cwd=plain), 2, '--project')
        self.expect(self.invoke('latest', '--project', str(plain)), 3, 'no current handoff')
        outside = self.root / 'outside'; outside.mkdir()
        (plain / '.handoff').symlink_to(outside, target_is_directory=True)
        self.expect(self.invoke('latest', '--project', str(plain)), 2, 'unsafe state')
        self.assertEqual([], list(outside.iterdir()))


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='handoff-install-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.binary = self.root / 'bin with spaces'
        self.environment = os.environ.copy()
        self.environment['PATH'] = str(self.binary) + os.pathsep + self.environment['PATH']

    def install(self, *arguments):
        return subprocess.run([BASH, str(REPO / 'scripts/install-handoff.sh'), '--bin-dir', str(self.binary),
                               *arguments], env=self.environment, capture_output=True, timeout=10)

    def test_dry_run_then_install_is_discoverable_and_repeatable(self):
        result = self.install('--dry-run')
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertFalse(self.binary.exists())
        for _ in range(2):
            result = self.install(); self.assertEqual(0, result.returncode, result.stderr)
        target = self.binary / 'ai-handoff'
        self.assertTrue(target.is_symlink())
        self.assertEqual(SCRIPT.resolve(), target.resolve())
        discovered = subprocess.check_output([BASH, '-c', 'command -v ai-handoff'], env=self.environment, text=True).strip()
        self.assertEqual(str(target), discovered)
        result = subprocess.run([str(target), '--help'], env=self.environment, capture_output=True)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_unmanaged_file_or_link_is_preserved(self):
        self.binary.mkdir()
        target = self.binary / 'ai-handoff'
        target.write_bytes(b'owned by user\n')
        result = self.install()
        self.assertEqual(1, result.returncode)
        self.assertEqual(b'owned by user\n', target.read_bytes())
        target.unlink()
        other = self.root / 'other'; other.write_text('other\n')
        target.symlink_to(other)
        result = self.install()
        self.assertEqual(1, result.returncode)
        self.assertEqual(other, target.resolve())

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lane', choices=('fast', 'slow', 'combined'), default='combined')
    parser.add_argument('--test')
    args = parser.parse_args()
    suite = unittest.TestSuite()
    for case in (HandoffTests, InstallerTests):
        for name in unittest.defaultTestLoader.getTestCaseNames(case):
            lane = 'slow' if name.startswith('test_native_') else 'fast'
            if (args.lane in ('combined', lane)) and (not args.test or args.test == name):
                suite.addTest(case(name))
    if not suite.countTestCases() and args.test:
        parser.error('test absent from selected lane')
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(not result.wasSuccessful())
