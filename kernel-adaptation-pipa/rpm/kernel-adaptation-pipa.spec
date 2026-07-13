# Prebuilt kernel packaging for Xiaomi Pad 6 (pipa)
# Place files under prebuilt/ before building the RPM:
#   prebuilt/boot/Image
#   prebuilt/boot/dtb/sm8250-xiaomi-pipa.dtb   (or your DTB name)
#   prebuilt/lib/modules/<kver>/...
#
# Source of prebuilts: pipa-pkgs linux-pipa, or extract from an existing
# EndeavourOS/Ultramarine/Nemo boot partition.

Name:           kernel-adaptation-pipa
Version:        6.14.0
Release:        1%{?dist}
Summary:        Linux kernel for Xiaomi Pad 6 (Sailfish OS)
License:        GPL-2.0-only
URL:            https://github.com/thespider2/pipa-pkgs
BuildArch:      aarch64

# No compile — package staged prebuilts
BuildRequires:  tar
Requires:       /bin/bash

%description
Kernel Image, DTB, and modules for Xiaomi Pad 6 mainline adaptation.
Boot path on device uses Mu-Silicium UEFI + GRUB; this package installs
kernel artifacts under /boot and /lib/modules for the flash packer / rootfs.

%prep
# Expect tree next to spec: ../prebuilt
%setup -q -c -T
mkdir -p prebuilt
if [ -d %{_sourcedir}/../prebuilt ]; then
  cp -a %{_sourcedir}/../prebuilt/. prebuilt/ || true
fi
if [ -d %{_builddir}/../prebuilt ]; then
  cp -a %{_builddir}/../prebuilt/. prebuilt/ || true
fi
# Also accept PREBUILT_DIR from environment via a stamp file written by build script
if [ -f %{_sourcedir}/prebuilt-path.txt ]; then
  src=$(cat %{_sourcedir}/prebuilt-path.txt)
  cp -a "$src"/. prebuilt/ || true
fi

%build
# nothing

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/boot %{buildroot}/lib/modules %{buildroot}/usr/share/kernel-adaptation-pipa

if [ ! -f prebuilt/boot/Image ] && [ ! -f prebuilt/Image ]; then
  # Placeholder so the package can still be built in CI scaffolding;
  # real Image must be supplied for a bootable device.
  echo "WARNING: no prebuilt Image — installing placeholder marker"
  echo "Replace with real pipa kernel before flashing" \
    > %{buildroot}/usr/share/kernel-adaptation-pipa/MISSING_PREBUILT
  mkdir -p %{buildroot}/boot
  : > %{buildroot}/boot/Image.placeholder
else
  if [ -f prebuilt/boot/Image ]; then
    install -Dm644 prebuilt/boot/Image %{buildroot}/boot/Image
  else
    install -Dm644 prebuilt/Image %{buildroot}/boot/Image
  fi
  if [ -d prebuilt/boot/dtb ]; then
    mkdir -p %{buildroot}/boot/dtb
    cp -a prebuilt/boot/dtb/. %{buildroot}/boot/dtb/
  elif [ -d prebuilt/dtb ]; then
    mkdir -p %{buildroot}/boot/dtb
    cp -a prebuilt/dtb/. %{buildroot}/boot/dtb/
  fi
  if [ -d prebuilt/lib/modules ]; then
    cp -a prebuilt/lib/modules/. %{buildroot}/lib/modules/
  fi
fi

# Helper used by flash packer
cat > %{buildroot}/usr/share/kernel-adaptation-pipa/README <<'EOF'
kernel-adaptation-pipa installs Image (+ optional dtb) under /boot and modules
under /lib/modules. The pipa flash packer copies these into the cust/boot
partition alongside GRUB; silicium.img still goes to boot_ab.
EOF

%files
/boot
/lib/modules
/usr/share/kernel-adaptation-pipa

%changelog
* Mon Jul 13 2026 Sailfish pipa porter <porter@local> - 6.14.0-1
- Initial prebuilt packaging for Xiaomi Pad 6
