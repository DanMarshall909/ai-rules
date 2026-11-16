#!/usr/bin/env bash
# Bash 3.2; Git for Git projects, common POSIX utilities otherwise.
set -uo pipefail
export LC_ALL=C
umask 077

die() { printf 'ai-handoff: %s\n' "$2" >&2; exit "$1"; }
usage() {
  cat <<'EOF'
usage: ai-handoff latest|list [--project PATH]
       ai-handoff new [--project PATH] --expect REVISION|none --from FILE [--owner ID]
       ai-handoff role [--metadata RESPONSE.json --thread ID]
EOF
}

unknown_role() {
  printf 'unknown\t%s\n' "${1:--}"
  printf 'ai-handoff: role unknown: %s\n' "$2" >&2
  return 7
}

classify_metadata() {
  local metadata=$1 thread=$2 label
  [[ "$thread" =~ ^[a-zA-Z0-9_-]+$ && ${#thread} -le 128 ]] || { unknown_role '-' 'no valid current Codex thread ID'; return 7; }
  command -v jq >/dev/null 2>&1 || { unknown_role "$thread" 'Codex discovery requires jq'; return 7; }
  label=$(jq -er --arg id "$thread" '
    .result.thread as $t |
    if ($t | type) != "object" or $t.id != $id then "unknown"
    elif (if ($t.source | type) == "object" then ($t.source | has("subAgent")) else false end) then "delegated"
    elif ($t.parentThreadId | type) == "string" and ($t.parentThreadId | length) > 0 then "delegated"
    elif ($t | has("parentThreadId")) and $t.parentThreadId == null and (["cli", "vscode", "exec", "appServer"] | index($t.source)) != null then "root"
    else "unknown" end
  ' "$metadata" 2>/dev/null) || label=unknown
  case "$label" in
    root) printf 'root\t%s\n' "$thread" ;;
    delegated) printf 'delegated\t%s\n' "$thread"; return 6 ;;
    *) unknown_role "$thread" 'missing, unsupported or mismatched thread metadata' ;;
  esac
}

# This optional host adapter performs initialize + thread/read only; no thread
# is started/resumed and no model turn is requested. Keep it outside core I/O.
codex_role() (
  local thread=$1 role_temp role_pid= line response_id deadline remaining initialized=0 status
  [[ "$thread" =~ ^[a-zA-Z0-9_-]+$ && ${#thread} -le 128 ]] || { unknown_role '-' 'no valid current Codex thread ID'; exit 7; }
  command -v jq >/dev/null 2>&1 && command -v codex >/dev/null 2>&1 || { unknown_role "$thread" 'Codex discovery requires codex and jq'; exit 7; }
  role_temp=$(mktemp -d "${TMPDIR:-/tmp}/ai-handoff-role.XXXXXX") || { unknown_role "$thread" 'cannot create private discovery temporary directory'; exit 7; }
  cleanup_role() {
    status=$?
    exec 7>&- 8>&-
    if [[ -n "$role_pid" ]]; then
      if kill -0 "$role_pid" 2>/dev/null; then
        kill -TERM "$role_pid" 2>/dev/null || :
        for pause in 1 2; do
          kill -0 "$role_pid" 2>/dev/null || break
          sleep 1
        done
        kill -KILL "$role_pid" 2>/dev/null || :
      fi
      wait "$role_pid" 2>/dev/null || :
    fi
    if ! rm -rf "$role_temp"; then
      printf 'ai-handoff: role discovery cleanup failed: %s\n' "$role_temp" >&2
      status=1
    fi
    exit "$status"
  }
  trap cleanup_role EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  mkfifo "$role_temp/input" "$role_temp/output" || { unknown_role "$thread" 'cannot create discovery pipes'; exit 7; }
  exec 7<> "$role_temp/input" 8<> "$role_temp/output" || { unknown_role "$thread" 'cannot open discovery pipes'; exit 7; }
  # Run in a private empty directory, not a project's configuration scope.
  (cd "$role_temp" && exec codex app-server --stdio) < "$role_temp/input" > "$role_temp/output" 2> "$role_temp/diagnostic" 7>&- 8>&- &
  role_pid=$!
  printf '%s\n' '{"id":0,"method":"initialize","params":{"clientInfo":{"name":"ai_handoff","version":"1"}}}' >&7
  deadline=$((SECONDS + 5))
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    remaining=$((deadline - SECONDS))
    IFS= read -r -t "$remaining" line <&8 || break
    response_id=$(printf '%s\n' "$line" | jq -r '.id // "notification"' 2>/dev/null) || break
    if [[ "$response_id" == 0 && "$initialized" == 0 ]]; then
      printf '%s\n' "$line" | jq -e 'has("result") and (has("error") | not)' >/dev/null 2>&1 || break
      initialized=1
      printf '%s\n' '{"method":"initialized"}' >&7
      jq -cn --arg thread "$thread" '{id:1,method:"thread/read",params:{threadId:$thread,includeTurns:false}}' >&7
    elif [[ "$response_id" == 1 && "$initialized" == 1 ]]; then
      printf '%s\n' "$line" > "$role_temp/response"
      classify_metadata "$role_temp/response" "$thread"
      exit $?
    fi
  done
  unknown_role "$thread" 'Codex metadata request failed or timed out'
)

command_name=${1:-}
[[ $# -gt 0 ]] && shift
project=; explicit_project=0; expected=; source_file=; owner=; metadata=; thread=${CODEX_THREAD_ID:-}; thread_option=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project|--expect|--from|--owner|--metadata|--thread)
      [[ $# -ge 2 && -n "$2" ]] || die 2 "$1 needs a value"
      case "$1" in
        --project) project=$2; explicit_project=1 ;;
        --expect) expected=$2 ;;
        --from) source_file=$2 ;;
        --owner) owner=$2 ;;
        --metadata) metadata=$2 ;;
        --thread) thread=$2; thread_option=1 ;;
      esac
      shift 2 ;;
    *) die 2 "unknown argument: $1" ;;
  esac
done
case "$command_name" in
  -h|--help|help) usage; exit 0 ;;
  role)
    [[ -z "$project$expected$source_file$owner" ]] || die 2 'project/write options do not apply to role'
    if [[ -n "$metadata" ]]; then classify_metadata "$metadata" "$thread"; exit $?; fi
    codex_role "$thread"; exit $? ;;
  latest|list|new) ;;
  *) die 2 'choose latest, list, new or role' ;;
esac
[[ -z "$metadata" && "$thread_option" == 0 ]] || die 2 'metadata/thread options apply only to role'
if [[ "$command_name" != new && -n "$expected$source_file$owner" ]]; then
  die 2 'write options require new'
fi

project=${project:-.}
project=$(cd -- "$project" 2>/dev/null && pwd -P) || die 2 'project directory is unavailable'
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE
if common=$(git -C "$project" rev-parse --git-common-dir 2>/dev/null); then
  case "$common" in /*) ;; *) common=$project/$common ;; esac
  common=$(cd "$common" && pwd -P) || die 2 'Git common directory is unavailable'
  state=$common/handoff
else
  [[ "$explicit_project" == 1 ]] || die 2 'non-Git projects require --project'
  [[ ! -e "$project/.git" && ! -L "$project/.git" ]] || die 2 'cannot resolve Git project'
  state=$project/.handoff
fi
current=$state/HANDOFF.md
archive=$state/archive
safe_directory() {
  [[ ! -L "$1" && ( ! -e "$1" || -d "$1" ) ]] || die 2 "unsafe state directory: $1"
}
safe_current() {
  [[ ! -L "$current" && ( ! -e "$current" || -f "$current" ) ]] || die 2 'unsafe current handoff'
}
safe_directory "$state"
safe_directory "$archive"
safe_current

snapshot=
revision=none
capture_text() {
  local value status
  # Keep the copy's exit status: read alone cannot distinguish EOF from EIO.
  # The sentinel preserves trailing newlines across command substitution.
  if snapshot=$(cat < "$1" | {
    value=
    if IFS= read -r -d '' value; then exit 2; fi
    printf '%s.' "$value"
  }); then
    snapshot=${snapshot%.}
  else
    status=$?
    [[ "$status" != 2 ]] || die 2 "$2 must be text without NUL bytes"
    die 1 "cannot read $2 completely"
  fi
}
calculate_revision() {
  local sum bytes checksum
  checksum=$(printf '%s' "$snapshot" | cksum) || die 1 'cannot calculate revision'
  read -r sum bytes <<< "$checksum"
  revision=$sum-$bytes
}
read_current() {
  snapshot=; revision=none
  [[ -e "$current" ]] || return 0
  capture_text "$current" 'current handoff'
  calculate_revision
}

list_archives() {
  if [[ -d "$archive" ]]; then
    for entry in "$archive"/*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      [[ ! -L "$entry" && -f "$entry" ]] || die 2 'unsafe archive entry'
      printf '%s\n' "$entry"
    done | sort -r | while IFS= read -r entry; do printf 'archive\t%s\n' "$entry"; done
  fi
}

staged=; backup_stage=; lock_owned=0
cleanup() {
  local status=$?
  for temporary in "$staged" "$backup_stage"; do
    if [[ -n "$temporary" ]] && ! rm -f "$temporary"; then
      printf 'ai-handoff: temporary cleanup failed: %s\n' "$temporary" >&2
      status=1
    fi
  done
  if [[ "$lock_owned" == 1 ]]; then
    if ! { rm -f "$state/lock/owner" && rmdir "$state/lock"; }; then
      printf 'ai-handoff: owned lock cleanup failed: %s\n' "$state/lock" >&2
      status=1
    fi
  fi
  exit "$status"
}

write_new() {
  local prepared_revision
  [[ "$expected" == none || "$expected" =~ ^[0-9]+-[0-9]+$ ]] || die 2 'new requires --expect revision or none'
  [[ -n "$source_file" && ! -L "$source_file" && -f "$source_file" && -r "$source_file" ]] || die 2 'prepared handoff must be a readable regular file'
  if [[ -n "${CODEX_THREAD_ID:-}" ]]; then
    local role_result role_status detected detected_owner
    if role_result=$(codex_role "$CODEX_THREAD_ID"); then
      IFS=$'\t' read -r detected detected_owner <<< "$role_result"
      [[ "$detected" == root && "$detected_owner" == "$CODEX_THREAD_ID" ]] || die 7 'current Codex root owner could not be established'
      [[ -z "$owner" || "$owner" == "$detected_owner" ]] || die 6 'root owner does not match current Codex thread'
      owner=$detected_owner
    else
      role_status=$?
      [[ "$role_status" != 6 ]] || die 6 'delegated agents must hand back to their parent; no handoff write'
      die 7 'current Codex root owner could not be established; no handoff write'
    fi
  fi
  [[ -n "$owner" ]] || die 7 'unknown role: an explicit root owner is required'
  [[ "$owner" =~ ^[a-zA-Z0-9:._-]+$ && ${#owner} -le 128 ]] || die 2 'invalid root owner identity'

  mkdir -p "$state" || die 1 'cannot create handoff state'
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  staged=$(mktemp "$state/.new.XXXXXX") || die 1 'cannot stage prepared handoff'
  cat < "$source_file" > "$staged" || die 1 'cannot read prepared handoff'
  capture_text "$staged" 'prepared handoff'
  [[ "$snapshot" =~ [^[:space:]] ]] || die 2 'prepared handoff is empty or whitespace'
  calculate_revision
  prepared_revision=$revision
  mkdir "$state/lock" 2>/dev/null || die 4 "handoff lock held: $state/lock; inspect its owner before manual recovery"
  lock_owned=1
  printf 'Owner: %s\nPID: %s\n' "$owner" "$$" > "$state/lock/owner" || die 1 'cannot record lock owner'
  safe_current
  safe_directory "$archive"
  read_current
  [[ "$revision" == "$expected" ]] || die 5 "revision mismatch: expected $expected, current $revision; read latest and reconcile"
  mkdir -p "$archive" || die 1 'cannot create archive directory'
  local entry name number maximum=0 next archive_file
  for entry in "$archive"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    name=${entry##*/}
    [[ ! -L "$entry" && -f "$entry" && "$name" =~ ^[0-9]{8}\.[a-zA-Z0-9]+$ ]] || die 2 'unsafe archive entry'
    number=${name%%.*}
    number=$((10#$number))
    [[ "$number" -le "$maximum" ]] || maximum=$number
  done
  if [[ "$revision" != none ]]; then
    [[ "$maximum" -lt 99999999 ]] || die 1 'archive sequence exhausted'
    printf -v next '%08d' "$((maximum + 1))"
    backup_stage=$(mktemp "$state/.archive.XXXXXX") || die 1 'cannot stage archive'
    printf '%s' "$snapshot" > "$backup_stage" || die 1 'cannot copy previous handoff'
    archive_file=$archive/$next.${backup_stage##*.}
    # Publish a complete, independent copy without ever replacing an archive.
    ln "$backup_stage" "$archive_file" || die 1 'cannot publish archive'
    rm "$backup_stage" || die 1 'cannot release archive staging file'
    backup_stage=
  fi
  mv -f "$staged" "$current" || die 1 'cannot replace current handoff'
  staged=
  printf 'Current: %s\nRevision: %s\nOwner: %s\n' "$current" "$prepared_revision" "$owner"
}

case "$command_name" in
  latest|list)
    read_current
    if [[ "$revision" == none ]]; then
      if [[ "$command_name" == list ]]; then list_archives || exit $?; fi
      die 3 "no current handoff: $current"
    fi
    if [[ "$command_name" == latest ]]; then
      printf 'Current: %s\nRevision: %s\n\n%s' "$current" "$revision" "$snapshot"
    else
      printf 'current\t%s\t%s\n' "$current" "$revision"
      list_archives
    fi
    ;;
  new) write_new ;;
esac
