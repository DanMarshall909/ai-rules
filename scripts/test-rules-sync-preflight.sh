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
printf 'two\n' >> "$SEED/content.txt"
git -C "$SEED" commit -qam remote-change
git -C "$SEED" push -q
run_check
if [[ $CODE -ne 0 && "$OUTPUT" == *remote* ]]; then ok "remote movement alerts"; else no "remote movement alerts" "code=$CODE output=$OUTPUT"; fi

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
git -C "$REPO" remote set-url origin "$ROOT/missing.git"
run_check
if [[ $CODE -ne 0 && "$OUTPUT" == *"could not query"* ]]; then ok "unverifiable remote alerts"; else no "unverifiable remote alerts" "code=$CODE output=$OUTPUT"; fi

echo ""
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
