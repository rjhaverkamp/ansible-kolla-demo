#!/usr/bin/env bats
# Unit tests for lib/config.sh

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=lib/log.sh
  source "$ROOT/lib/log.sh"
  # shellcheck source=lib/config.sh
  source "$ROOT/lib/config.sh"
  unset VM_NAME VCPUS RAM_MB DISK_GB KOLLA_AIO_STAGE
}

@test "load_config applies defaults when unset" {
  load_config
  [ "$VM_NAME" = "kolla-aio" ]
  [ "$VCPUS" = "8" ]
  [ "$RAM_MB" = "16384" ]
  [ "$DISK_GB" = "80" ]
  [ "$KOLLA_AIO_STAGE" = "provision" ]
}

@test "load_config honors env overrides" {
  VCPUS=4 RAM_MB=8192 DISK_GB=40 VM_NAME=demo load_config
  [ "$VCPUS" = "4" ]
  [ "$RAM_MB" = "8192" ]
  [ "$DISK_GB" = "40" ]
  [ "$VM_NAME" = "demo" ]
}

@test "validate_config rejects non-numeric VCPUS" {
  run bash -c "source '$ROOT/lib/log.sh'; source '$ROOT/lib/config.sh'; VCPUS=abc load_config"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VCPUS must be a positive integer"* ]]
}

@test "validate_config rejects too-small RAM" {
  run bash -c "source '$ROOT/lib/log.sh'; source '$ROOT/lib/config.sh'; RAM_MB=512 load_config"
  [ "$status" -ne 0 ]
  [[ "$output" == *"RAM_MB must be >= 2048"* ]]
}

@test "validate_config rejects unknown stage" {
  run bash -c "source '$ROOT/lib/log.sh'; source '$ROOT/lib/config.sh'; KOLLA_AIO_STAGE=bogus load_config"
  [ "$status" -ne 0 ]
  [[ "$output" == *"KOLLA_AIO_STAGE must be one of"* ]]
}

@test "stage_at_least compares stages in order" {
  KOLLA_AIO_STAGE=config load_config
  run stage_at_least provision
  [ "$status" -eq 0 ]
  run stage_at_least config
  [ "$status" -eq 0 ]
  run stage_at_least deploy
  [ "$status" -ne 0 ]
}
