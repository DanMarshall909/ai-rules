"""Exercise the actual EXIT/finally cleanup boundaries with tiny owned fixtures."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash') if os.name != 'nt' else r'C:\Program Files\Git\bin\bash.exe'
PWSH = shutil.which('pwsh')


def bash_path(path):
    if os.name == 'nt':
        drive, tail = os.path.splitdrive(os.path.abspath(path))
        if not re.fullmatch(r'[A-Za-z]:', drive):
            raise ValueError('fixture probes require a local Windows drive')
        return '/' + drive[0].lower() + tail.replace('\\', '/')
    return str(path)


class CleanupTests(unittest.TestCase):
    scripts = ()
    shell = ''

    def run_cleanup(self, name, target, intended_parent, leave_residue=False, initial_status=0):
        source = (ROOT / 'scripts' / name).read_text(encoding='utf-8-sig')
        env = dict(os.environ, FIXTURE=str(target), FIXTURE_PARENT=str(intended_parent), PROBE_ROOT=str(ROOT), PROBE_SCRIPTS=str(ROOT / 'scripts'))
        if self.shell == 'bash':
            match = re.search(r'^cleanup\(\) \{\n.*?^\}', source, re.M | re.S)
            self.assertIsNotNone(match, 'owning script must expose its EXIT cleanup function')
            env.update(FIXTURE=bash_path(target), FIXTURE_PARENT=bash_path(intended_parent), PROBE_ROOT=bash_path(ROOT))
            command = 'set -uo pipefail\nREPO="$PROBE_ROOT"\nFIXTURE_TEMP_ROOT="$(cd "$FIXTURE_PARENT" && pwd -P)"\nSANDBOXES=("$FIXTURE")\n'
            if leave_residue:
                command += 'rm() { return 0; }\n'
            command += match[0] + '\ntrap cleanup EXIT\nexit ' + str(initial_status)
            return subprocess.run([BASH, '-c', command], env=env, text=True, capture_output=True, timeout=20)
        start = source.rfind('finally {') + len('finally {')
        end = source.index('\n}\n\nWrite-Host', start)
        self.assertGreaterEqual(start, len('finally {'))
        prefix = source.split('\ntry {\n', 1)[0].replace('$PSScriptRoot', '$env:PROBE_SCRIPTS')
        command = prefix + '\n$script:sandboxes = @($env:FIXTURE)\n$fixtureTempRoot = [System.IO.Path]::GetFullPath($env:FIXTURE_PARENT).TrimEnd([System.IO.Path]::DirectorySeparatorChar)\n'
        if leave_residue:
            command += 'function Remove-Item { [CmdletBinding()] param([string]$LiteralPath, [switch]$Recurse, [switch]$Force) }\n'
        command += source[start:end] + '\nWrite-Output ("test_failures=" + $script:fail)\nif ($script:fail -gt 0 -or $script:cleanupFailures -gt 0) { exit 1 }; exit ' + str(initial_status)
        return subprocess.run([PWSH, '-NoProfile', '-Command', command], env=env, text=True, capture_output=True, timeout=20)

    def fixture(self, parent, name):
        prefix = 'iskill-' if name == 'test-install-skill.ps1' else 'rules-sync-' if name.endswith('.ps1') else 'ai-rules-test.'
        path = Path(tempfile.mkdtemp(prefix=prefix, dir=parent))
        (path / 'evidence.txt').write_text('owned test output', encoding='utf-8')
        return path

    def test_residue_is_a_cleanup_failure(self):
        with tempfile.TemporaryDirectory(prefix='ai-rules-cleanup-probe-') as parent:
            for name in self.scripts:
                with self.subTest(script=name):
                    target = self.fixture(parent, name)
                    result = self.run_cleanup(name, target, parent, leave_residue=True)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn('cleanup', (result.stdout + result.stderr).lower())
                    self.assertTrue(target.is_dir(), 'failed deletion must leave evidence visible')
                    if self.shell == 'pwsh':
                        self.assertIn('test_failures=0', result.stdout, 'cleanup must not impersonate a failed application assertion')

    def test_cleanup_keeps_original_failure_and_removes_own_fixture(self):
        with tempfile.TemporaryDirectory(prefix='ai-rules-cleanup-probe-') as parent:
            for name in self.scripts:
                with self.subTest(script=name):
                    target = self.fixture(parent, name)
                    result = self.run_cleanup(name, target, parent, initial_status=7)
                    self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
                    self.assertFalse(target.exists(), result.stdout + result.stderr)

    def test_outside_root_is_retained_and_reported(self):
        with tempfile.TemporaryDirectory(prefix='ai-rules-cleanup-probe-') as parent:
            intended = Path(parent) / 'intended'
            intended.mkdir()
            for name in self.scripts:
                with self.subTest(script=name):
                    target = self.fixture(parent, name)
                    result = self.run_cleanup(name, target, intended)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn('cleanup', (result.stdout + result.stderr).lower())
                    self.assertTrue((target / 'evidence.txt').exists())

    def test_linked_outside_content_survives(self):
        with tempfile.TemporaryDirectory(prefix='ai-rules-cleanup-probe-') as parent:
            outside = Path(parent) / 'outside'
            outside.mkdir()
            marker = outside / 'keep.txt'
            marker.write_text('not owned by cleanup', encoding='utf-8')
            for name in self.scripts:
                with self.subTest(script=name):
                    target = self.fixture(parent, name)
                    link = target / 'external-skill'
                    if os.name == 'nt':
                        env = dict(os.environ, PROBE_LINK=str(link), PROBE_TARGET=str(outside))
                        subprocess.run([PWSH, '-NoProfile', '-Command', 'New-Item -ItemType Junction -Path $env:PROBE_LINK -Target $env:PROBE_TARGET | Out-Null'], env=env, check=True, capture_output=True, timeout=15)
                    else:
                        link.symlink_to(outside, target_is_directory=True)
                    result = self.run_cleanup(name, target, parent)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertTrue(marker.exists(), 'cleanup followed a link outside its fixture')
                    self.assertFalse(target.exists())


class BashCleanupTests(CleanupTests):
    scripts = ('test-build-agents.sh', 'test-install-skill.sh')
    shell = 'bash'


@unittest.skipUnless(PWSH, 'PowerShell is unavailable on this host')
class PowerShellCleanupTests(CleanupTests):
    scripts = ('test-install-skill.ps1', 'test-rules-sync-preflight.ps1')
    shell = 'pwsh'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lane', choices=('fast', 'slow', 'combined'), default='combined')
    parser.add_argument('--test', choices=unittest.defaultTestLoader.getTestCaseNames(CleanupTests))
    args = parser.parse_args()
    suite = unittest.TestSuite()
    # Link probes start PowerShell on Windows; keep those process-heavy boundaries
    # with the native PowerShell checks in the slow lane.
    fast_names = {'test_residue_is_a_cleanup_failure', 'test_outside_root_is_retained_and_reported'}
    for case in (BashCleanupTests, PowerShellCleanupTests):
        for name in unittest.defaultTestLoader.getTestCaseNames(case):
            lane = 'fast' if case is BashCleanupTests and name in fast_names else 'slow'
            if (args.lane == 'combined' or args.lane == lane) and (not args.test or args.test == name):
                suite.addTest(case(name))
    if not suite.countTestCases():
        parser.error('the selected test is not in this lane')
    raise SystemExit(not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful())
