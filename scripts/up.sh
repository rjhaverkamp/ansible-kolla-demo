#!/usr/bin/env bash
# Boot (or converge) the kolla-aio VM up to $KOLLA_AIO_STAGE.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=lib/config.sh
source "$ROOT/lib/config.sh"
# shellcheck source=lib/template.sh
source "$ROOT/lib/template.sh"
# shellcheck source=lib/image.sh
source "$ROOT/lib/image.sh"
# shellcheck source=lib/libvirt.sh
source "$ROOT/lib/libvirt.sh"

provision_vm() {
  mkdir -p "$CACHE_DIR"
  ensure_network "$NETWORK"

  if domain_exists "$VM_NAME"; then
    log_info "domain '$VM_NAME' already exists; converging"
    domain_running "$VM_NAME" || virsh start "$VM_NAME" >/dev/null
  else
    fetch_image
    log_info "creating overlay disk (${DISK_GB}G) backed by base image"
    qemu-img create -q -f qcow2 -F qcow2 -b "$IMAGE_PATH" "$DISK_PATH" "${DISK_GB}G" \
      || die "failed to create overlay disk"

    log_info "rendering cloud-init user-data"
    render_template "$ROOT/templates/user-data.yaml.tmpl" >"$USERDATA_PATH"

    log_info "creating domain '$VM_NAME' (${VCPUS} vCPU, ${RAM_MB} MB) on network '$NETWORK'"
    virt-install \
      --name "$VM_NAME" \
      --memory "$RAM_MB" \
      --vcpus "$VCPUS" \
      --os-variant "$OS_VARIANT" \
      --disk "path=$DISK_PATH,format=qcow2,bus=virtio" \
      --network "network=$NETWORK,model=virtio" \
      --cloud-init "user-data=$USERDATA_PATH" \
      --graphics none \
      --console pty,target_type=serial \
      --import \
      --noautoconsole \
      || die "virt-install failed"
  fi

  local ip
  log_info "waiting for DHCP lease on '$NETWORK'..."
  ip=$(wait_for_lease "$VM_NAME" 300) || die "VM did not acquire a DHCP lease within timeout"
  log_info "VM '$VM_NAME' is up at ${ip}"
}

main() {
  load_config
  require_cmds virsh virt-install qemu-img
  log_info "stage target: $KOLLA_AIO_STAGE"

  provision_vm

  if stage_at_least bootstrap; then
    log_warn "stage 'bootstrap' is not implemented yet; stopping after 'provision'"
  fi
}

main "$@"
