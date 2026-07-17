Name:           kernel-adaptation-pipa
Version:        7.1.0
Release:        0.placeholder
Summary:        DO NOT BUILD — use kernel-adaptation-pipa/scripts/pack-rpm.sh
License:        GPL-2.0-only
BuildArch:      noarch

# This bootstrap stub used to install a few-byte /boot/Image that zypper then
# overwrote a working kernel with (black screen after U-Boot). The real RPM is
# built by kernel-adaptation-pipa/scripts/pack-rpm.sh from linux-pipa.

%description
Placeholder removed. Build the real package with:
  KERNEL_PKG=... bash kernel-adaptation-pipa/scripts/pack-rpm.sh

%prep
echo "Refusing to build placeholder kernel-adaptation-pipa" >&2
exit 1

%build

%install

%files

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 7.1.0-0.placeholder
- Refuse to build; real Image comes from pack-rpm.sh
