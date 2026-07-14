Name:           droid-config-pipa
Version:        0.1.3
Release:        1
Summary:        Sailfish OS device config for Xiaomi Pad 6 (pipa)
License:        BSD
BuildArch:      noarch
Source0:        sparse.tar.gz

Requires:       openssh-server
Requires:       kmod
Requires:       usb-moded

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
* Tue Jul 14 2026 Porter <porter@local> - 0.1.3-1
- WiFi/connman, UCM, multimedia v4l2src, SSU adaptation feature, QT services
* Mon Jul 13 2026 Porter <porter@local> - 0.1.2-1
- Avoid /boot directory conflict with filesystem package
* Mon Jul 13 2026 Porter <porter@local> - 0.1.1-1
- Minimal Requires for SFOS 5.0 mic
