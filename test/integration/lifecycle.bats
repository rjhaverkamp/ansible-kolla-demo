#!/usr/bin/env bats
# KVM-tagged integration: full VM lifecycle on a real libvirt host.
# Skipped unless KOLLA_AIO_KVM_TESTS=1. Boots and destroys a throwaway VM.

setup() {
  [ -n "${KOLLA_AIO_KVM_TESTS:-}" ] || skip "set KOLLA_AIO_KVM_TESTS=1 on a KVM host to run"
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export VM_NAME="${VM_NAME:-kolla-aio-itest}"
  export KOLLA_AIO_STAGE=provision
}

@test "make up yields a virbr0 DHCP lease, make destroy removes the domain" {
  run "$ROOT/scripts/up.sh"
  [ "$status" -eq 0 ]

  run "$ROOT/scripts/smoke.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SMOKE PASS"* ]]

  run "$ROOT/scripts/destroy.sh"
  [ "$status" -eq 0 ]

  run virsh dominfo "$VM_NAME"
  [ "$status" -ne 0 ]
}
