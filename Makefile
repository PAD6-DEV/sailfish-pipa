SDK_IMAGE ?= coderus/sailfishos-platform-sdk-base:4.6.0.13

.PHONY: help sdk-pull sdk-verify repo

help:
	@echo "All image builds run on GitHub Actions (no local mic/uboot/mesa)."
	@echo "  Workflow: .github/workflows/build-rootfs.yml"
	@echo "  Artifact: sailfish-pipa-flash"
	@echo "    u-boot-xiaomi-pipa.img -> boot_ab"
	@echo "    sfos_rootfs.raw       -> linux  (Mesa freedreno injected)"
	@echo
	@echo "Flash: bash flash/flash.sh /path/to/artifact"

sdk-pull:
	docker pull $(SDK_IMAGE)

sdk-verify:
	./scripts/verify-mic.sh

repo:
	./scripts/createrepo-local.sh
