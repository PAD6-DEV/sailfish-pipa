# sailfish-pipa image-ci

MIC / kickstart builder for Xiaomi Pad 6, following
[dont_be_evil-ci](https://gitlab.com/sailfishos-porters-ci/dont_be_evil-ci/).

## GitHub Actions (preferred)

Workflow: `.github/workflows/build-rootfs.yml`

- Image: `coderus/sailfishos-platform-sdk-base:4.6.0.13`
- Builds adaptation RPMs (best-effort) → local `repo/adaptation` → `mic` → artifacts

Trigger: push to `main`/`master`, or **Actions → Build Sailfish pipa rootfs → Run workflow**.

## Local (Platform SDK container)

```bash
source root.env
source pipa/pipa.env
export WORKING_DIRECTORY=pipa
./run-mic.sh
```

Release: see `root.env` (`RELEASE=5.0.0.77`).
