SDK_IMAGE ?= coderus/sailfishos-platform-sdk-base:4.6.0.13

.PHONY: sdk-pull sdk-verify repo mic-help flash-help

sdk-pull:
	docker pull $(SDK_IMAGE)

sdk-verify:
	./scripts/verify-mic.sh

repo:
	./scripts/createrepo-local.sh

mic-help:
	@echo "source image-ci/root.env && source image-ci/pipa/pipa.env"
	@echo "export WORKING_DIRECTORY=pipa && cd image-ci && ./run-mic.sh"

flash-help:
	@echo "./flash/pack-rootfs.sh <sfe-tarball> ./flash/out"
	@echo "./flash/flash.sh ./flash/out"
