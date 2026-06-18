#!/usr/bin/env bats
# Unit tests for lib/image.sh checksum verification (no network).

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=lib/log.sh
  source "$ROOT/lib/log.sh"
  # shellcheck source=lib/image.sh
  source "$ROOT/lib/image.sh"
  TMP="$(mktemp -d)"
  printf 'pristine image bytes\n' >"$TMP/image.img"
  GOOD_SUM="$(sha256sum "$TMP/image.img" | awk '{print $1}')"
}

teardown() {
  rm -rf "$TMP"
}

@test "verify_checksum accepts a matching sha256" {
  run verify_checksum "$TMP/image.img" "$GOOD_SUM"
  [ "$status" -eq 0 ]
}

@test "verify_checksum rejects a tampered file" {
  printf 'tampered\n' >>"$TMP/image.img"
  run verify_checksum "$TMP/image.img" "$GOOD_SUM"
  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch"* ]]
}

@test "verify_checksum fails on a missing file" {
  run verify_checksum "$TMP/does-not-exist.img" "$GOOD_SUM"
  [ "$status" -ne 0 ]
  [[ "$output" == *"image not found"* ]]
}
