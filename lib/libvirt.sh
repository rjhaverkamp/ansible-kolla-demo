#!/usr/bin/env bash
# libvirt/virsh helpers. Source me; do not execute.

# domain_exists NAME: succeed if a libvirt domain NAME is defined.
domain_exists() {
  virsh dominfo "$1" >/dev/null 2>&1
}

# domain_running NAME: succeed if domain NAME is running.
domain_running() {
  virsh domstate "$1" 2>/dev/null | grep -q 'running'
}

# ensure_network NET: verify the libvirt network exists and is active (start it if not).
ensure_network() {
  local net=$1
  virsh net-info "$net" >/dev/null 2>&1 || die "libvirt network '$net' not found (is libvirtd running?)"
  if ! virsh net-info "$net" 2>/dev/null | grep -qi 'Active:.*yes'; then
    log_info "starting libvirt network '$net'"
    virsh net-start "$net" >/dev/null || die "could not start libvirt network '$net'"
  fi
}

# domain_mac NAME: print the MAC of the domain's first network interface.
domain_mac() {
  virsh domiflist "$1" 2>/dev/null | awk '/network|bridge/ {print $5; exit}'
}

# get_vm_ip NAME: print the domain's IPv4 lease on $NETWORK, or fail if none yet.
get_vm_ip() {
  local name=$1 mac ip
  mac=$(domain_mac "$name")
  [[ -n $mac ]] || return 1
  ip=$(virsh net-dhcp-leases "$NETWORK" 2>/dev/null \
    | awk -v m="$mac" 'tolower($0) ~ tolower(m) {print $5}' | cut -d/ -f1 | head -n1)
  [[ -n $ip ]] || return 1
  printf '%s\n' "$ip"
}

# wait_for_lease NAME [TIMEOUT_S]: poll until the domain has a DHCP lease; print the IP.
wait_for_lease() {
  local name=$1 timeout=${2:-180} waited=0 ip
  while ((waited < timeout)); do
    if ip=$(get_vm_ip "$name"); then
      printf '%s\n' "$ip"
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  return 1
}
