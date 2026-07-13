Name:           kernel-adaptation-pipa
Version:        6.14.0
Release:        1
Summary:        Linux kernel artifacts for Xiaomi Pad 6 (placeholder/prebuilt)
License:        GPL-2.0-only
BuildArch:      noarch
Source0:        Image

%description
CI/bootstrap kernel package. Replaced by real Image+modules when staged.

%prep

%build

%install
mkdir -p %{buildroot}/boot %{buildroot}/usr/share/kernel-adaptation-pipa
if [ -f %{SOURCE0} ]; then
  install -m 644 %{SOURCE0} %{buildroot}/boot/Image
else
  echo placeholder > %{buildroot}/boot/Image
fi
echo "kernel-adaptation-pipa bootstrap" > %{buildroot}/usr/share/kernel-adaptation-pipa/README

%files
/boot/Image
/usr/share/kernel-adaptation-pipa/README

%changelog
* Mon Jul 13 2026 Porter <porter@local> - 6.14.0-1
- Bootstrap kernel package
