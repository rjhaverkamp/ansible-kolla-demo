#!/usr/bin/env bats
# Unit tests for lib/template.sh rendering.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=lib/log.sh
  source "$ROOT/lib/log.sh"
  # shellcheck source=lib/template.sh
  source "$ROOT/lib/template.sh"
  TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP"
}

@test "render_template expands VM_NAME" {
  printf 'hostname: ${VM_NAME}\n' >"$TMP/t.tmpl"
  VM_NAME=kolla-aio run render_template "$TMP/t.tmpl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hostname: kolla-aio"* ]]
}

@test "render_template fails on a missing template" {
  run render_template "$TMP/nope.tmpl"
  [ "$status" -ne 0 ]
  [[ "$output" == *"template not found"* ]]
}
