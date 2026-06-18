#!/usr/bin/env bash
# Slice 1 smoke test: assert the VM has a virbr0 DHCP lease.
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

  domain_exists "$VM_NAME" || die "domain '$VM_NAME' does not exist; run 'make up' first"

  local ip
  ip=$(get_vm_ip "$VM_NAME") || die "SMOKE FAIL: no DHCP lease for '$VM_NAME' on '$NETWORK'"
  log_info "SMOKE PASS: '$VM_NAME' has a lease on '$NETWORK' at ${ip}"
  printf '%s\n' "$ip"
}

main "$@"
