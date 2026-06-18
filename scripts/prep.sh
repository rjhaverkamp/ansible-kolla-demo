#!/usr/bin/env bash
# Install host dependencies for running the kolla-aio VM.
# Runtime deps by default; add --dev for the lint/test toolchain (shellcheck/shfmt/bats).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/log.sh
source "$ROOT/lib/log.sh"

WITH_DEV=0
for arg in "$@"; do
  case "$arg" in
    --dev) WITH_DEV=1 ;;
    -h | --help)
      echo "usage: $0 [--dev]"
      echo "  --dev  also install the lint/test toolchain (shellcheck, shfmt, bats)"
      exit 0
      ;;
    *) die "unknown argument: $arg" ;;
  esac
done

# sudo wrapper that is a no-op when already root.
SUDO=""
if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || die "need root or sudo to install packages"
  SUDO="sudo"
fi

detect_pm() {
  if command -v apt-get >/dev/null 2>&1; then
    echo apt
  elif command -v dnf >/dev/null 2>&1; then
    echo dnf
  else
    die "no supported package manager found (need apt-get or dnf)"
  fi
}

install_runtime() {
  local pm=$1
  case "$pm" in
    apt)
      log_info "installing runtime packages via apt"
      $SUDO apt-get update -qq
      $SUDO apt-get install -y \
        qemu-system-x86 qemu-utils \
        libvirt-daemon-system libvirt-clients \
        virtinst
      ;;
    dnf)
      log_info "installing runtime packages via dnf"
      $SUDO dnf install -y \
        qemu-kvm qemu-img \
        libvirt libvirt-client \
        virt-install
      ;;
  esac
}

install_dev() {
  local pm=$1
  log_info "installing dev toolchain (shellcheck, shfmt, bats)"
  case "$pm" in
    apt) $SUDO apt-get install -y shellcheck bats ;;
    dnf) $SUDO dnf install -y ShellCheck bats ;;
  esac
  if ! command -v shfmt >/dev/null 2>&1; then
    local dest=/usr/local/bin/shfmt
    log_info "fetching shfmt to $dest"
    $SUDO curl -fsSL -o "$dest" \
      https://github.com/mvdan/sh/releases/download/v3.8.0/shfmt_v3.8.0_linux_amd64
    $SUDO chmod +x "$dest"
  fi
}

enable_libvirt() {
  if command -v systemctl >/dev/null 2>&1; then
    log_info "enabling and starting libvirtd"
    $SUDO systemctl enable --now libvirtd >/dev/null 2>&1 || log_warn "could not enable libvirtd via systemctl"
  fi

  # Ensure the default NAT network (virbr0) exists on the system connection.
  # prep runs virsh as root, which uses qemu:///system where virbr0 lives.
  if ! $SUDO virsh net-info default >/dev/null 2>&1; then
    local xml=/usr/share/libvirt/networks/default.xml
    if [[ -f $xml ]]; then
      log_info "defining libvirt 'default' network from $xml"
      $SUDO virsh net-define "$xml" || log_warn "could not define 'default' network"
    else
      log_warn "libvirt 'default' network not found and $xml missing; reinstall libvirt-daemon-system"
    fi
  fi
  # Start it and enable autostart (idempotent).
  $SUDO virsh net-info default 2>/dev/null | grep -qi 'Active:.*yes' || $SUDO virsh net-start default || true
  $SUDO virsh net-info default 2>/dev/null | grep -qi 'Autostart:.*yes' || $SUDO virsh net-autostart default || true
}

add_groups() {
  [[ $EUID -eq 0 ]] && return 0
  local user=${SUDO_USER:-$USER} g
  for g in libvirt kvm; do
    if getent group "$g" >/dev/null 2>&1 && ! id -nG "$user" | tr ' ' '\n' | grep -qx "$g"; then
      log_info "adding $user to group '$g' (log out/in for it to take effect)"
      $SUDO usermod -aG "$g" "$user" || log_warn "could not add $user to '$g'"
    fi
  done
}

main() {
  local pm
  pm=$(detect_pm)
  install_runtime "$pm"
  ((WITH_DEV)) && install_dev "$pm"
  enable_libvirt
  add_groups
  log_info "prep complete. If you were added to new groups, start a new login session, then run 'make up'."
}

main "$@"
