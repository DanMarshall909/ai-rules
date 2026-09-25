#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")/.."
SOURCE="$PWD/skills/upgrade-global-skills/scripts/check-rules-sync.sh"
SANDBOXES=()
pass=0
fail=0

ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  FAIL %s\n       %s\n' "$1" "$2"; }
cleanup() { for path in "${SANDBOXES[@]:-}"; do [[ -n "$path" ]] && rm -rf "$path"; done; }
trap cleanup EXIT

new_fixture() {
  ROOT="$(mktemp -d)"
  SANDBOXES+=("$ROOT")
  REMOTE="$ROOT/remote.git"
  SEED="$ROOT/seed"
  REPO="$ROOT/repo"
  git init --bare -q "$REMOTE"
  git -C "$REMOTE" symbolic-ref HEAD refs/heads/main
  git init -q "$SEED"
  git -C "$SEED" config user.name Test
  git -C "$SEED" config user.email test@example.invalid
  git -C "$SEED" config core.autocrlf false
  printf 'one\n' > "$SEED/content.txt"
  mkdir -p "$SEED/skills/upgrade-global-skills/scripts"
  cp "$SOURCE" "$SEED/skills/upgrade-global-skills/scripts/check-rules-sync.sh"
  git -C "$SEED" add content.txt skills/upgrade-global-skills/scripts/check-rules-sync.sh
  git -C "$SEED" commit -qm initial
  git -C "$SEED" branch -M main
  git -C "$SEED" remote add origin "$REMOTE"
  git -C "$SEED" push -qu origin main
  git -c core.autocrlf=false clone -q "$REMOTE" "$REPO"
  git -C "$REPO" config user.name Test
  git -C "$REPO" config user.email test@example.invalid
  git -C "$REPO" config core.autocrlf false
  CHECK="$REPO/skills/upgrade-global-skills/scripts/check-rules-sync.sh"
}

run_check() {
  OUTPUT="$(bash "$CHECK" 2>&1)"
  CODE=$?
}

fetch_state() {
  local fetch_head
  fetch_head="$(git -C "$REPO" rev-parse --git-path FETCH_HEAD)"
  [[ "$fetch_head" == /* ]] || fetch_head="$REPO/$fetch_head"
  if [[ -f "$fetch_head" ]]; then git -C "$REPO" hash-object --no-filters "$fetch_head"; else printf 'absent'; fi
}

echo "rules sync preflight (bash)"

new_fixture
run_check
if [[ $CODE -eq 0 && -z "$OUTPUT" ]]; then ok "exact sync is silent"; else no "exact sync is silent" "code=$CODE output=$OUTPUT"; fi

new_fixture
ln -s "$REPO/skills/upgrade-global-skills" "$ROOT/installed-skill"
if [[ -L "$ROOT/installed-skill" ]]; then
  CHECK="$ROOT/installed-skill/scripts/check-rules-sync.sh"
  run_check
  if [[ $CODE -eq 0 && -z "$OUTPUT" ]]; then ok "installed symlink resolves silently"; else no "installed symlink resolves silently" "code=$CODE output=$OUTPUT"; fi
else
  ok "installed symlink check skipped (host did not create a symlink)"
fi

new_fixture
fetch_before="$(fetch_state)"
git -C "$REPO" fetch -q origin HEAD
fetch_after="$(fetch_state)"
if [[ "$fetch_after" != "$fetch_before" ]]; then ok "FETCH_HEAD oracle rejects a fetch fault"; else no "FETCH_HEAD oracle rejects a fetch fault" "FETCH_HEAD stayed $fetch_before"; fi

new_fixture
tracking_before="$(git -C "$REPO" rev-parse refs/remotes/origin/main)"
fetch_before="$(fetch_state)"
printf 'two\n' >> "$SEED/content.txt"
git -C "$SEED" commit -qam remote-change
git -C "$SEED" push -q
run_check
if [[ $CODE -ne 0 && "$OUTPUT" == *"differ; fetch and reconcile"* ]]; then ok "remote movement alerts"; else no "remote movement alerts" "code=$CODE output=$OUTPUT"; fi
tracking_after="$(git -C "$REPO" rev-parse refs/remotes/origin/main)"
fetch_after="$(fetch_state)"
if [[ "$tracking_after" == "$tracking_before" && "$fetch_after" == "$fetch_before" ]]; then ok "remote check changes no refs or FETCH_HEAD"; else no "remote check changes no refs or FETCH_HEAD" "tracking=$tracking_before->$tracking_after FETCH_HEAD=$fetch_before->$fetch_after"; fi

new_fixture
printf 'local\n' >> "$REPO/content.txt"
git -C "$REPO" commit -qam local-change
run_check
if [[ $CODE -ne 0 && "$OUTPUT" == *"not pushed"* ]]; then ok "unpushed commits alert"; else no "unpushed commits alert" "code=$CODE output=$OUTPUT"; fi

new_fixture
printf 'dirty\n' >> "$REPO/content.txt"
run_check
if [[ $CODE -ne 0 && "$OUTPUT" == *"not committed"* ]]; then ok "uncommitted work alerts"; else no "uncommitted work alerts" "code=$CODE output=$OUTPUT"; fi

new_fixture
printf 'invalid index\n' > "$REPO/.git/index"
run_check
if [[ $CODE -ne 0 && "$OUTPUT" == *"could not inspect"* ]]; then ok "failed status inspection alerts"; else no "failed status inspection alerts" "code=$CODE output=$OUTPUT"; fi

new_fixture
git -C "$REPO" remote set-url origin "$ROOT/missing.git"
run_check
if [[ $CODE -ne 0 && "$OUTPUT" == *"could not query"* ]]; then ok "unverifiable remote alerts"; else no "unverifiable remote alerts" "code=$CODE output=$OUTPUT"; fi

new_fixture
git -C "$REPO" remote set-url origin "ssh://example.invalid/repo"
hang_pid_file="$ROOT/hang.pid"
hang_ssh="$ROOT/hang-ssh.sh"
cat > "$hang_ssh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$$" > "$HANG_PID_FILE"
exec sleep 6
EOF
chmod +x "$hang_ssh"
started=$SECONDS
old_git_ssh_command_set="${GIT_SSH_COMMAND+x}"
old_git_ssh_command="${GIT_SSH_COMMAND:-}"
old_hang_pid_file_set="${HANG_PID_FILE+x}"
old_hang_pid_file="${HANG_PID_FILE:-}"
old_timeout_set="${AI_RULES_SYNC_TIMEOUT_SECONDS+x}"
old_timeout="${AI_RULES_SYNC_TIMEOUT_SECONDS:-}"
export GIT_SSH_COMMAND="$hang_ssh"
export HANG_PID_FILE="$hang_pid_file"
export AI_RULES_SYNC_TIMEOUT_SECONDS=1
run_check
elapsed=$((SECONDS - started))
if [[ -n "$old_git_ssh_command_set" ]]; then export GIT_SSH_COMMAND="$old_git_ssh_command"; else unset GIT_SSH_COMMAND; fi
if [[ -n "$old_hang_pid_file_set" ]]; then export HANG_PID_FILE="$old_hang_pid_file"; else unset HANG_PID_FILE; fi
if [[ -n "$old_timeout_set" ]]; then export AI_RULES_SYNC_TIMEOUT_SECONDS="$old_timeout"; else unset AI_RULES_SYNC_TIMEOUT_SECONDS; fi
hang_pid="$(cat "$hang_pid_file" 2>/dev/null || true)"
for _ in {1..10}; do
  [[ -z "$hang_pid" ]] || ! kill -0 "$hang_pid" 2>/dev/null || sleep 0.1
done
transport_alive=0
[[ -n "$hang_pid" ]] && kill -0 "$hang_pid" 2>/dev/null && transport_alive=1
if [[ $CODE -eq 1 && "$OUTPUT" == *"timed out"* && "$OUTPUT" == *"sync is unverified"* && $elapsed -lt 5 && -n "$hang_pid" && $transport_alive -eq 0 ]]; then
  ok "stalled remote times out and stops its transport"
else
  no "stalled remote times out and stops its transport" "code=$CODE elapsed=${elapsed}s pid=${hang_pid:-missing} output=$OUTPUT"
  [[ $transport_alive -eq 1 ]] && kill -KILL "$hang_pid" 2>/dev/null || true
fi

echo ""
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
