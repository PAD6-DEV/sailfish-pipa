# CI build

Repo: https://github.com/PAD6-DEV/sailfish-pipa

GitHub Actions builds a Sailfish rootfs like [dont_be_evil-ci](https://gitlab.com/sailfishos-porters-ci/dont_be_evil-ci/):

1. `coderus/sailfishos-platform-sdk-base:4.6.0.13` via Docker on `ubuntu-24.04`
2. Bootstrap RPMs (`bootstrap/`) → `repo/adaptation`
3. `mic create fs` from `image-ci/pipa/` kickstart
4. Artifact `sailfish-pipa-rootfs` (tarball + optional flash raws)

Workflow: `.github/workflows/build-rootfs.yml`
