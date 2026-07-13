# Sailfish OS rootfs CI for Xiaomi Pad 6 (pipa)

Modeled on [dont_be_evil-ci](https://gitlab.com/sailfishos-porters-ci/dont_be_evil-ci/).

```bash
source root.env
source pipa/pipa.env
export WORKING_DIRECTORY=pipa
./run-mic.sh
```

Requires adaptation RPMs in `../repo/adaptation` (createrepo) or change the
kickstart `file://` repo to a published OBS URL.
