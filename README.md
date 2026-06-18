# ansible-kolla-demo

Stand up a disposable, single-host OpenStack on your Linux workstation. One command boots an
Ubuntu 22.04 VM under libvirt/QEMU on the default NAT network (`virbr0`), installs
kolla-ansible, and deploys an all-in-one **OpenStack 2024.1 (Caracal)** control plane inside
that VM. The end goal is a Horizon login page you can reach from the host.

The environment is throwaway: `make destroy` removes it cleanly, so the build/test cycle is
repeatable.

> **Status:** under construction. Delivery is sliced (see `docs/specs/001-local-kolla-aio-vm.md`).
> A run proceeds only as far as the `KOLLA_AIO_STAGE` gate allows; unfinished stages are not
> reachable yet.

## Requirements (host)

- Linux with KVM: `libvirt`, `qemu-kvm`, `virt-install`, `virsh`, and an active `virbr0` NAT network.
- Nested virtualisation enabled (`kvm_intel nested=1` / `kvm_amd nested=1`).
- ≥ 16 GB RAM free and ≥ 80 GB disk for the VM (configurable).
- Tooling for development/tests: `make`, `shellcheck`, `shfmt`, `bats`.

## Usage

```sh
make up        # boot the VM on virbr0 (runs up to $KOLLA_AIO_STAGE)
make verify    # check Horizon reachability + print credentials (when implemented)
make destroy   # remove the VM, disks, and cloud-init seed
```

### Configuration

All knobs are environment variables with defaults:

| Variable          | Default      | Meaning                                              |
|-------------------|--------------|------------------------------------------------------|
| `KOLLA_AIO_STAGE` | `provision`  | How far a run proceeds: `provision`→`bootstrap`→`config`→`deploy`→`verify` |
| `VM_NAME`         | `kolla-aio`  | libvirt domain name                                  |
| `VCPUS`           | `8`          | vCPUs                                                 |
| `RAM_MB`          | `16384`      | Memory (MB)                                           |
| `DISK_GB`         | `80`         | Root disk size (GB)                                  |

## Development

```sh
make lint   # shellcheck + shfmt --diff
make test   # bats unit tests (integration tests are KVM-tagged)
```

CI (GitHub Actions) runs `lint` + unit `test` on every push. The full nested-KVM deploy cannot
run on GitHub-hosted runners; validate it with `make verify` on a KVM-capable host.

## Layout

```
docs/specs/   # delivery spec and slices
lib/          # shared shell helpers (config, image, libvirt)
scripts/      # stage scripts (provision, install, deploy, verify)
templates/    # cloud-init + kolla config templates
test/         # bats tests
```

## Out of scope

Multinode/HA, TLS/production hardening, provider networks beyond NAT, upgrades, and state
persistence across `make destroy`. See the spec for the full list.
