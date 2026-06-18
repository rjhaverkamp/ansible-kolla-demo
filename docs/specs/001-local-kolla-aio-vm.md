# Spec 001: Local kolla-ansible all-in-one in a QEMU VM

**Date:** 2026-06-18
**Status:** Draft
**Owner:** Rob Haverkamp / Safespring
**Feature flag:** none — incomplete work is gated by the `KOLLA_AIO_STAGE` run boundary (see below)

## Foundations assessment

**Project context:** Greenfield (empty, non-git directory)
**Build abstraction:** missing — proposed: `Makefile` (`make up`, `make destroy`, `make test`, `make lint`, `make deploy`, `make verify`)
**CI pipeline:** missing — proposed: GitHub Actions (`.github/workflows/ci.yml`) running `shellcheck` + `shfmt --diff` + `bats` on every push; full nested-KVM deploy is out of CI scope and validated on a KVM-capable host
**Test framework:** missing — proposed: `bats-core` for unit/integration of shell logic; `shellcheck` + `shfmt` as quality gates
**Deploy path:** missing — proposed: the script *is* the deploy; "production-like target" = the script run on a real KVM-capable host producing a reachable VM/Horizon. CI proves static + unit; a manual `make verify` on a KVM host is the highest-fidelity gate.
**Feature flags:** not used — no production users to protect in a developer-run script. Incomplete behaviour lands on trunk safely because `KOLLA_AIO_STAGE` (`provision|bootstrap|config|deploy|verify`) bounds how far a run proceeds; a not-yet-finished stage simply isn't reachable. The stage default advances as each slice lands.
**Trunk discipline:** gap: no repo yet. Proposed: initialise git, trunk-based development, merge to `main` within 1 day per slice.
**Quality gates:** gaps: no formatter, linter, type-check, or vuln scan. Proposed: `shfmt` (format), `shellcheck` (lint), checksum-pinned cloud image (supply-chain), no secrets in repo.
**Biggest constraint (brownfield only):** N/A — greenfield.
**Foundation slices required before / alongside feature work:** Slice 1 (Feature Zero) — pipeline + build abstraction + bats harness + lint + a disposable VM lifecycle (`make up`/`make destroy`) proven against real libvirt — before any kolla work.

## Goal

Provide a single command that stands up a disposable OpenStack environment on a developer's
Linux host. The script boots an Ubuntu 22.04 VM under libvirt/QEMU on the default NAT network
(`virbr0`), installs kolla-ansible, and deploys an all-in-one OpenStack 2024.1 (Caracal)
control plane inside that VM. Success is a Horizon login page reachable from the host over
`virbr0`, with the script printing the URL and admin password. The environment is throwaway:
`make destroy` removes it cleanly so the cycle is repeatable.

## Acceptance criteria

- [ ] `make up` on a fresh KVM-capable host boots an Ubuntu 22.04 VM on `virbr0` and the VM gets a DHCP lease.
- [ ] The VM is sized 8 vCPU / 16 GB RAM / 80 GB disk (overridable via env vars) with nested virtualisation enabled.
- [ ] kolla-ansible (Caracal / 2024.1) is installed in the VM and `bootstrap-servers` completes.
- [ ] Generated `globals.yml` + `passwords.yml` pass `kolla-ansible prechecks`.
- [ ] `kolla-ansible deploy` completes with all containers healthy and `openstack token issue` succeeds.
- [ ] Horizon login page returns HTTP 200 from the host over `virbr0`.
- [ ] The script prints the Horizon URL and the admin password on success.
- [ ] `make destroy` removes the VM, its disks, and the cloud-init seed, leaving no residue.

## Out of scope

- Multinode / HA kolla deployments.
- TLS, production hardening, secret management beyond a local `passwords.yml`.
- Provider/external networks for guest instances beyond what NAT provides.
- OpenStack upgrades, state persistence across `destroy`, or data backup.
- Non-libvirt networking (raw qemu user-net, manual bridge) — explicitly chosen against.
- Hosts without KVM/nested-virt support.

## Constraints and assumptions

- Host runs Linux with `libvirt`, `qemu-kvm`, `virsh`, and the default `virbr0` NAT network active.
- Host has ≥ 16 GB RAM free and nested virtualisation enabled (`kvm_intel nested=1` / `kvm_amd nested=1`).
- Guest base: Ubuntu 22.04 LTS cloud image, pinned by SHA256 checksum.
- OpenStack release pinned to 2024.1 (Caracal); kolla-ansible installed from the matching stable branch/release.
- Networking: libvirt default NAT (`virbr0`); Horizon reached at the VM's 192.168.122.x address.
- Assumption: CI cannot run nested KVM, so the full deploy is gated to a manual `make verify` on a KVM host; CI enforces only static analysis and unit tests. (Stated explicitly.)
- Assumption: kolla AIO uses Docker as the container engine (kolla default) inside the VM. (Stated explicitly.)
- Assumption: success check is reachability + creds print (HTTP 200 on login, print URL/password), not an authenticated login flow. (Per Phase 1 answer.)

## Vertical slices

Each slice is independently deployable in ≤ 2 days, bounded by the `KOLLA_AIO_STAGE` gate.

Slice ordering: Greenfield → Slice 1 is **Feature Zero**. No feature slice precedes it. Each
later slice advances `KOLLA_AIO_STAGE` one step and is verifiable by an automated check. The
default stage advances only when a slice is complete, so unfinished stages are never reachable
on trunk.

### Slice 1: Feature Zero — toolchain and disposable VM lifecycle

- **Value:** A developer can `make up` to boot a throwaway VM on `virbr0` and `make destroy` it, with lint + unit tests running in CI on every push. Establishes the standard every later line of script is written to.
- **Acceptance:**
  - [ ] `make lint` runs `shellcheck` + `shfmt --diff`; `make test` runs `bats` with ≥ 1 passing test.
  - [ ] `.github/workflows/ci.yml` runs lint + test on every push, blocking on failure.
  - [ ] `make up` boots a minimal Ubuntu 22.04 cloud-init VM on `virbr0`; smoke test asserts the VM acquires a `virbr0` DHCP lease.
  - [ ] `make destroy` removes the VM, disk, and seed ISO; re-running `make up` succeeds (idempotent lifecycle).
  - [ ] Cloud image pinned by SHA256; config (name, sizing) read from env vars with defaults.
  - [ ] Stage convention documented: `KOLLA_AIO_STAGE` (`provision|bootstrap|config|deploy|verify`), default `provision`.
- **Estimate:** ~2 days
- **Stage gate:** `KOLLA_AIO_STAGE=provision` is the only stage wired and the default; no kolla work runs.
- **Dependencies:** none

#### TDD plan

1. 🔴 RED — bats unit `parses VCPUS/RAM/DISK env vars with defaults` (fails: no arg-parsing function exists).
2. 🟢 GREEN — add `lib/config.sh` with a `load_config` function reading env vars, defaults 8/16/80.
3. 🔴 RED — bats unit `verifies cloud image checksum and rejects a tampered file` (fails: no checksum guard).
4. 🟢 GREEN — add `fetch_image` with SHA256 verification in `lib/image.sh`.
5. 🟢 GREEN — add `Makefile` targets `lint`/`test`/`up`/`destroy` and `.github/workflows/ci.yml` running `shellcheck`/`shfmt`/`bats`.
6. 🔴 RED — bats integration (KVM-tagged) `make up yields a virbr0 DHCP lease for the VM` (fails: no boot logic).
7. 🟢 GREEN — implement `up.sh` using `virt-install`/`virsh` + cloud-init seed on `virbr0`.
8. 🔴 RED — bats integration `make destroy leaves no domain, disk, or seed` (fails: no teardown).
9. 🟢 GREEN — implement `destroy.sh` (`virsh destroy/undefine --remove-all-storage`, seed cleanup).
10. 🔵 REFACTOR — extract shared `virsh` helpers into `lib/libvirt.sh` *(optional)*.
11. Integrate to trunk (`KOLLA_AIO_STAGE` default: `provision`).

### Slice 2: Provision a kolla-ready, correctly-sized host VM

- **Value:** A developer gets a VM that already meets kolla's prerequisites — right size, nested virt, second disk, SSH ready — verifiable before any kolla install.
- **Acceptance:**
  - [ ] VM provisioned at 8 vCPU / 16 GB / 80 GB (env-overridable) with CPU passthrough for nested virt.
  - [ ] cloud-init creates a deploy user with the host's SSH key and installs base prereqs (python3, etc.).
  - [ ] A prereq check asserts: nested virt available in guest, ≥ 2 NICs/addresses or a usable kolla network interface, and required free disk.
  - [ ] `make up` is idempotent: re-running converges without duplicate domains.
- **Estimate:** ~1.5 days
- **Stage gate:** `KOLLA_AIO_STAGE=provision` extended; still no kolla install.
- **Dependencies:** Slice 1

#### TDD plan

1. 🔴 RED — bats unit `cloud-init user-data injects host SSH key and deploy user` (fails: minimal seed only).
2. 🟢 GREEN — template cloud-init user-data with SSH key + deploy user in `templates/user-data.yaml.tmpl`.
3. 🔴 RED — bats integration `guest reports nested virt enabled` (fails: default CPU model, no nesting).
4. 🟢 GREEN — set `--cpu host-passthrough` (or equivalent) in the domain definition.
5. 🔴 RED — bats integration `prereq check passes on the provisioned VM` (fails: no prereq script).
6. 🟢 GREEN — add `scripts/prereq-check.sh` run over SSH asserting virt/disk/network.
7. 🔵 REFACTOR — consolidate SSH-exec helper *(optional)*.
8. Integrate to trunk (`KOLLA_AIO_STAGE` default: `provision`).

### Slice 3: Install kolla-ansible and bootstrap the host

- **Value:** kolla-ansible (Caracal) and its dependencies (Docker) are installed in the VM and `bootstrap-servers` completes — the host is container-ready.
- **Acceptance:**
  - [ ] kolla-ansible installed from the 2024.1 stable branch/release into a Python venv in the VM.
  - [ ] Ansible Galaxy kolla dependencies installed.
  - [ ] `kolla-ansible bootstrap-servers` completes; Docker is running in the VM.
  - [ ] Stage gated by `KOLLA_AIO_STAGE=bootstrap`.
- **Estimate:** ~2 days
- **Stage gate:** runs only when `KOLLA_AIO_STAGE>=bootstrap`; default advances to `bootstrap` when this slice lands.
- **Dependencies:** Slice 2

#### TDD plan

1. 🔴 RED — bats unit `install step pins kolla-ansible to the 2024.1 branch` (fails: no installer).
2. 🟢 GREEN — add `scripts/install-kolla.sh` creating a venv and pip-installing pinned kolla-ansible + galaxy deps.
3. 🔴 RED — bats integration `bootstrap-servers leaves Docker active in the VM` (fails: not invoked).
4. 🟢 GREEN — wire `kolla-ansible bootstrap-servers` with a generated AIO inventory.
5. 🔵 REFACTOR — extract remote-command runner / logging *(optional)*.
6. Integrate to trunk (`KOLLA_AIO_STAGE` default: `bootstrap`).

### Slice 4: Generate AIO config and pass prechecks

- **Value:** A valid Caracal AIO configuration for the `virbr0` topology exists and `kolla-ansible prechecks` passes — deployment is proven feasible before the long deploy.
- **Acceptance:**
  - [ ] `globals.yml` generated for AIO on the VM's interfaces (kolla internal VIP / network interface set correctly for the NAT topology).
  - [ ] `passwords.yml` generated via `kolla-genpwd`; admin password retrievable.
  - [ ] `kolla-ansible prechecks` passes.
  - [ ] Stage gated by `KOLLA_AIO_STAGE=config`.
- **Estimate:** ~2 days
- **Stage gate:** runs when `KOLLA_AIO_STAGE>=config`; default advances to `config` when this slice lands.
- **Dependencies:** Slice 3

#### TDD plan

1. 🔴 RED — bats unit `globals.yml renders with the VM's interface and Caracal release` (fails: no template).
2. 🟢 GREEN — add `templates/globals.yml.tmpl` + render step keyed off detected interface.
3. 🔴 RED — bats unit `passwords.yml is generated and admin password is extractable` (fails: no genpwd step).
4. 🟢 GREEN — invoke `kolla-genpwd`; add helper to read `keystone_admin_password`.
5. 🔴 RED — bats integration `kolla-ansible prechecks passes` (fails: config gaps).
6. 🟢 GREEN — fix config until prechecks pass; wire `prechecks` into the stage.
7. 🔵 REFACTOR — centralise templating *(optional)*.
8. Integrate to trunk (`KOLLA_AIO_STAGE` default: `config`).

### Slice 5: Deploy the all-in-one control plane

- **Value:** `kolla-ansible deploy` brings up the OpenStack control plane; the API is live and authentication works.
- **Acceptance:**
  - [ ] `kolla-ansible deploy` completes with all containers healthy.
  - [ ] `kolla-ansible post-deploy` writes `admin-openrc`; `openstack token issue` succeeds.
  - [ ] Deploy is re-runnable (re-deploy converges).
  - [ ] Stage gated by `KOLLA_AIO_STAGE=deploy`.
- **Estimate:** ~2 days (dev/automation effort; deploy machine-time is separate)
- **Stage gate:** runs when `KOLLA_AIO_STAGE>=deploy`; default advances to `deploy` when this slice lands.
- **Dependencies:** Slice 4

#### TDD plan

1. 🔴 RED — bats integration `kolla-ansible deploy completes and no container is unhealthy` (fails: deploy not invoked).
2. 🟢 GREEN — wire `kolla-ansible deploy`; add a container-health assertion over SSH.
3. 🔴 RED — bats integration `openstack token issue succeeds via admin-openrc` (fails: no post-deploy / auth).
4. 🟢 GREEN — run `post-deploy`, fetch `admin-openrc`, add token-issue check.
5. 🔵 REFACTOR — extract health-poll/wait helper *(optional)*.
6. Integrate to trunk (`KOLLA_AIO_STAGE` default: `deploy`).

### Slice 6: Reach Horizon and print credentials

- **Value:** The end goal — a developer can open the printed URL and log in to Horizon.
- **Acceptance:**
  - [ ] Horizon login page returns HTTP 200 from the host over `virbr0`.
  - [ ] Script prints the Horizon URL (VM IP) and the admin password on success.
  - [ ] `make verify` runs the reachability + creds-print check end to end.
  - [ ] Stage gated by `KOLLA_AIO_STAGE=verify`, which becomes the default once this slice lands.
- **Estimate:** ~1 day
- **Stage gate:** final stage; landing this slice advances the `KOLLA_AIO_STAGE` default to `verify` (full run).
- **Dependencies:** Slice 5

#### TDD plan

1. 🔴 RED — bats integration `Horizon login returns HTTP 200 over virbr0` (fails: no reachability check).
2. 🟢 GREEN — add `scripts/verify-horizon.sh` resolving the VM IP and curling the login page.
3. 🔴 RED — bats unit `success output prints Horizon URL and admin password` (fails: no summary output).
4. 🟢 GREEN — add a success-summary printer pulling URL + admin password.
5. 🔵 REFACTOR — unify the final reporting block *(optional)*.
6. Integrate to trunk; advance `KOLLA_AIO_STAGE` default to `verify`.

## Definition of Done (per slice)

- [ ] Integrated to trunk
- [ ] All tests pass in CI (lint + unit; KVM-tagged integration run on a KVM host)
- [ ] Deployable; unfinished behaviour bounded by the `KOLLA_AIO_STAGE` gate
- [ ] Documentation updated where user-visible (README run instructions)
- [ ] No follow-up tickets created for deferred edge cases within the slice's scope

## Risks

- **CI cannot run nested KVM** — integration/deploy stages can't gate on standard GitHub-hosted runners. Mitigation: CI enforces static + unit; designate a self-hosted KVM-capable runner or a documented `make verify` gate on a host for the integration tests.
- **kolla AIO deploy is slow and occasionally flaky** — long machine-time, transient failures. Mitigation: idempotent re-deploy, health-poll with timeout, clear logs; keep deploy automation thin over kolla's own commands.
- **Host resource exhaustion** — 16 GB VM on an under-provisioned host fails opaquely. Mitigation: preflight host RAM/disk check in `make up`; fail fast with a clear message.
- **virbr0 / NAT topology mismatch with kolla network config** — kolla expects a network interface for the internal VIP. Mitigation: detect the interface and template `globals.yml`; prechecks (Slice 4) catch misconfig before deploy.
- **Cloud image / release drift** — upstream image or kolla branch moves. Mitigation: pin image by SHA256 and kolla to the 2024.1 stable ref.

## Change log

- 2026-06-18 — initial draft
- 2026-06-18 — dropped the `local-kolla-aio` feature flag; incomplete work is gated by the `KOLLA_AIO_STAGE` run boundary instead
- 2026-06-18 — CI target set to GitHub Actions (repo hosted on GitHub)
