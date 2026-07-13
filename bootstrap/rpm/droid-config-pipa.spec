Name:           droid-config-pipa
Version:        0.1.2
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
# filesystem owns /boot; only ship contents
rm -rf %{buildroot}/boot
mkdir -p %{buildroot}/boot/extlinux
if [ -f sparse/boot/extlinux/extlinux.conf ]; then
  cp -a sparse/boot/extlinux/extlinux.conf %{buildroot}/boot/extlinux/
elif [ -f boot/extlinux/extlinux.conf ]; then
  cp -a boot/extlinux/extlinux.conf %{buildroot}/boot/extlinux/
fi

# Do not package directory nodes owned by filesystem (/, /boot, /etc, …)
# List only payload prefixes so we never conflict on /boot itself.
%files
%defattr(-,root,root,-)
/boot/extlinux
/etc
/usr
/lib
/var

%changelog
* Mon Jul 13 2026 Porter <porter@local> - 0.1.2-1
- Avoid /boot directory conflict with filesystem package
* Mon Jul 13 2026 Porter <porter@local> - 0.1.1-1
- Minimal Requires for SFOS 5.0 mic
