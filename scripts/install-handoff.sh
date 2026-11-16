#!/usr/bin/env bash
# Install a live command link; never replace an unmanaged file or link.
set -uo pipefail
bin_dir=${HOME:?HOME must identify the user}/.local/bin
dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bin-dir) [[ $# -ge 2 && -n "$2" ]] || exit 2; bin_dir=$2; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) printf 'usage: install-handoff.sh [--bin-dir PATH] [--dry-run]\n'; exit 0 ;;
    *) printf 'install-handoff: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 1
source_file=$repo/skills/session-handoff/scripts/ai-handoff.sh
[[ -f "$source_file" && -x "$source_file" ]] || { printf 'install-handoff: source is not executable\n' >&2; exit 1; }
case "$bin_dir" in /*) ;; *) bin_dir=$PWD/$bin_dir ;; esac
target=$bin_dir/ai-handoff
if [[ -L "$target" && "$(readlink "$target")" == "$source_file" ]]; then
  printf 'Already installed: %s\n' "$target"
  exit 0
fi
if [[ -e "$target" || -L "$target" ]]; then
  printf 'install-handoff: preserving unmanaged target: %s\n' "$target" >&2
  exit 1
fi
if [[ "$dry_run" == 1 ]]; then
  printf 'Would link: %s -> %s\n' "$target" "$source_file"
  exit 0
fi
mkdir -p "$bin_dir" && ln -s "$source_file" "$target" || exit 1
if [[ ! -L "$target" || "$(readlink "$target")" != "$source_file" ]]; then
  printf 'install-handoff: native symlink unavailable; inspect retained target: %s\n' "$target" >&2
  exit 1
fi
printf 'Installed: %s\n' "$target"
if [[ "$(command -v ai-handoff || :)" != "$target" ]]; then
  printf 'Add this directory to PATH, or invoke the absolute command: %s\n' "$bin_dir"
fi
