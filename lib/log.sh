#!/usr/bin/env bash
# Shared logging + small guards. Source me; do not execute.

log_info() { printf '\033[1;34m[info]\033[0m %s\n' "$*" >&2; }
log_warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
log_error() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
die() {
  log_error "$*"
  exit 1
}

# require_cmds CMD...: die unless every command is on PATH.
require_cmds() {
  local c missing=()
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  if ((${#missing[@]})); then
    die "required command(s) not found: ${missing[*]}"
  fi
}
