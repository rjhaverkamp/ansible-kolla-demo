SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# All shell sources we lint/format.
SH_FILES := $(shell find lib scripts test -name '*.sh' 2>/dev/null)
SHFMT_FLAGS := -i 2 -ci -bn

.PHONY: help prep prep-dev lint fmt test test-integration up smoke destroy

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

prep: ## Install host runtime dependencies (libvirt, qemu, virtinst)
	./scripts/prep.sh

prep-dev: ## Install runtime deps plus the lint/test toolchain
	./scripts/prep.sh --dev

lint: ## shellcheck + shfmt diff (non-mutating)
	shellcheck -x $(SH_FILES)
	shfmt $(SHFMT_FLAGS) -d $(SH_FILES)

fmt: ## Format shell sources in place
	shfmt $(SHFMT_FLAGS) -w $(SH_FILES)

test: ## Run unit bats tests
	bats test/unit

test-integration: ## Run KVM-tagged integration bats tests (needs a KVM host)
	KOLLA_AIO_KVM_TESTS=1 bats test/integration

up: ## Boot/converge the VM up to $$KOLLA_AIO_STAGE
	./scripts/up.sh

smoke: ## Assert the VM has a virbr0 DHCP lease
	./scripts/smoke.sh

destroy: ## Remove the VM and generated artifacts
	./scripts/destroy.sh
