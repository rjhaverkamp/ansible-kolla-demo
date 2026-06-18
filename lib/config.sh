#!/usr/bin/env bash
# Configuration with env-var overrides and defaults. Source me; do not execute.

# Ordered delivery stages. A run proceeds up to $KOLLA_AIO_STAGE.
KOLLA_AIO_STAGES=(provision bootstrap config deploy verify)

# stage_index STAGE: print the position of STAGE in KOLLA_AIO_STAGES, or fail.
stage_index() {
  local s=$1 i
  for i in "${!KOLLA_AIO_STAGES[@]}"; do
    if [[ ${KOLLA_AIO_STAGES[$i]} == "$s" ]]; then
      printf '%s\n' "$i"
      return 0
    fi
  done
  return 1
}

# stage_at_least STAGE: succeed if the requested KOLLA_AIO_STAGE is at or past STAGE.
stage_at_least() {
  local want cur
  want=$(stage_index "$1") || return 2
  cur=$(stage_index "${KOLLA_AIO_STAGE:-provision}") || return 2
  ((cur >= want))
}

# load_config: populate and export all knobs, applying defaults for unset vars.
load_config() {
  : "${VM_NAME:=kolla-aio}"
  : "${VCPUS:=8}"
  : "${RAM_MB:=16384}"
  : "${DISK_GB:=80}"
  : "${KOLLA_AIO_STAGE:=provision}"
  : "${NETWORK:=default}" # libvirt NAT network backing virbr0
  : "${OS_VARIANT:=ubuntu22.04}"
  : "${IMAGE_URL:=https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img}"
  : "${IMAGE_SHA256:=}" # optional pin; verified when set
  : "${CACHE_DIR:=${PWD}/.cache}"
  : "${IMAGE_PATH:=${CACHE_DIR}/$(basename "$IMAGE_URL")}"
  : "${DISK_PATH:=${CACHE_DIR}/${VM_NAME}.qcow2}"
  : "${USERDATA_PATH:=${CACHE_DIR}/${VM_NAME}-user-data.yaml}"

  export VM_NAME VCPUS RAM_MB DISK_GB KOLLA_AIO_STAGE NETWORK OS_VARIANT
  export IMAGE_URL IMAGE_SHA256 CACHE_DIR IMAGE_PATH DISK_PATH USERDATA_PATH

  validate_config
}

# validate_config: reject obviously-wrong values early.
validate_config() {
  [[ $VCPUS =~ ^[0-9]+$ && $VCPUS -ge 1 ]] || die "VCPUS must be a positive integer (got: $VCPUS)"
  [[ $RAM_MB =~ ^[0-9]+$ && $RAM_MB -ge 2048 ]] || die "RAM_MB must be >= 2048 (got: $RAM_MB)"
  [[ $DISK_GB =~ ^[0-9]+$ && $DISK_GB -ge 20 ]] || die "DISK_GB must be >= 20 (got: $DISK_GB)"
  stage_index "$KOLLA_AIO_STAGE" >/dev/null \
    || die "KOLLA_AIO_STAGE must be one of: ${KOLLA_AIO_STAGES[*]} (got: $KOLLA_AIO_STAGE)"
}
