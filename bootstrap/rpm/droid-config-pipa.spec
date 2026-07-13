Name:           droid-config-pipa
Version:        0.1.1
Release:        1
Summary:        Sailfish OS device config for Xiaomi Pad 6 (pipa)
License:        BSD
BuildArch:      noarch
Source0:        sparse.tar.gz

Requires:       openssh-server
Requires:       kmod

%description
Sparse overlays and services for Xiaomi Pad 6 Sailfish OS port.

%prep
%setup -q -c -n sparse -T
tar -xzf %{SOURCE0} -C .

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
if [ -d sparse ]; then
  cp -a sparse/. %{buildroot}/
else
  cp -a . %{buildroot}/
  rm -f %{buildroot}/sparse.tar.gz
fi
[ -f %{buildroot}/usr/bin/usb-rndis-gadget.sh ] && chmod 755 %{buildroot}/usr/bin/usb-rndis-gadget.sh

%files
/*

%changelog
* Mon Jul 13 2026 Porter <porter@local> - 0.1.1-1
- Minimal Requires for SFOS 5.0 mic
