#!/usr/bin/env bash
set -uo pipefail
export GIT_TERMINAL_PROMPT=0

alerted=0
alert() {
  printf 'AI rules sync attention: %s\n' "$1"
  alerted=1
}

script_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [[ -z "${script_dir}" ]]; then
  alert "could not resolve the installed preflight script."
  exit 1
fi

repo="$(git -C "${script_dir}" rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "${repo}" ]]; then
  alert "could not locate the durable ai-rules checkout."
  exit 1
fi

remote="origin"
if ! git -C "${repo}" remote get-url "${remote}" >/dev/null 2>&1; then
  alert "the durable checkout has no '${remote}' remote."
  exit 1
fi

status="$(git -C "${repo}" status --porcelain --untracked-files=normal 2>/dev/null)"
if [[ -n "${status}" ]]; then
  alert "the durable checkout has local changes that are not committed or pushed."
fi

remote_info="$(git -C "${repo}" ls-remote --symref "${remote}" HEAD 2>/dev/null)"
if [[ $? -ne 0 || -z "${remote_info}" ]]; then
  alert "could not query the '${remote}' remote; sync is unverified."
  exit 1
fi

default_ref="$(awk '$1 == "ref:" && $3 == "HEAD" { print $2; exit }' <<<"${remote_info}")"
remote_sha="$(awk '$2 == "HEAD" && $1 != "ref:" { print $1; exit }' <<<"${remote_info}")"
if [[ -z "${default_ref}" || -z "${remote_sha}" ]]; then
  alert "the '${remote}' remote did not advertise a default branch; sync is unverified."
  exit 1
fi

default_branch="${default_ref#refs/heads/}"
local_sha="$(git -C "${repo}" rev-parse HEAD 2>/dev/null)"
if [[ -z "${local_sha}" ]]; then
  alert "could not read the durable checkout's current commit."
  exit 1
fi

current_branch="$(git -C "${repo}" branch --show-current 2>/dev/null)"
if [[ "${current_branch}" != "${default_branch}" ]]; then
  shown_branch="${current_branch:-detached HEAD}"
  alert "the durable checkout is on '${shown_branch}', while ${remote}/HEAD is '${default_branch}'."
fi

if [[ "${local_sha}" != "${remote_sha}" ]]; then
  if git -C "${repo}" merge-base --is-ancestor "${remote_sha}" "${local_sha}" >/dev/null 2>&1; then
    alert "local commits are not pushed to ${remote}/${default_branch}."
  elif git -C "${repo}" merge-base --is-ancestor "${local_sha}" "${remote_sha}" >/dev/null 2>&1; then
    alert "the remote ${remote}/${default_branch} has newer commits."
  else
    alert "the local checkout and remote ${remote}/${default_branch} differ; fetch and reconcile them."
  fi
fi

[[ ${alerted} -eq 0 ]]
