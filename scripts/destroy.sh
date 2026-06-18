#!/usr/bin/env bash
# Remove the kolla-aio VM and its generated artifacts. Safe to run when nothing exists.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=lib/config.sh
source "$ROOT/lib/config.sh"
# shellcheck source=lib/libvirt.sh
source "$ROOT/lib/libvirt.sh"

main() {
  load_config
  require_cmds virsh

  if domain_exists "$VM_NAME"; then
    log_info "destroying domain '$VM_NAME'"
    virsh destroy "$VM_NAME" >/dev/null 2>&1 || true
    # Prefer nvram + storage removal; fall back for domains without nvram.
    virsh undefine "$VM_NAME" --nvram --remove-all-storage >/dev/null 2>&1 \
      || virsh undefine "$VM_NAME" --remove-all-storage >/dev/null 2>&1 \
      || virsh undefine "$VM_NAME" >/dev/null 2>&1 \
      || die "failed to undefine domain '$VM_NAME'"
  else
    log_info "domain '$VM_NAME' not present; nothing to destroy"
  fi

  rm -f "$DISK_PATH" "$USERDATA_PATH"
  log_info "removed generated artifacts (overlay disk, user-data); base image cache kept"
}

main "$@"
