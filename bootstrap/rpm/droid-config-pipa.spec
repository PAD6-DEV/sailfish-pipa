Name:           droid-config-pipa
Version:        0.1.0
Release:        1
Summary:        Sailfish OS device config for Xiaomi Pad 6 (pipa)
License:        BSD
BuildArch:      noarch
Source0:        sparse.tar.gz

Requires:       mesa-dri-drivers
Requires:       mesa-libEGL
Requires:       mesa-libGLESv2
Requires:       qt5-plugin-platform-eglfs
Requires:       usb-moded
Requires:       openssh-server
Requires:       kmod

%description
Sparse overlays and services for Xiaomi Pad 6 Sailfish OS port
(eglfs, mce gconf, USB RNDIS, display-on).

%prep
%setup -q -c -n sparse -T
tar -xzf %{SOURCE0} -C .

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
# sparse tree is rooted at ./sparse or .
if [ -d sparse ]; then
  cp -a sparse/. %{buildroot}/
else
  cp -a . %{buildroot}/
  rm -f %{buildroot}/sparse.tar.gz
fi
# Ensure scripts executable
if [ -f %{buildroot}/usr/bin/usb-rndis-gadget.sh ]; then
  chmod 755 %{buildroot}/usr/bin/usb-rndis-gadget.sh
fi

%files
/*

%changelog
* Mon Jul 13 2026 Porter <porter@local> - 0.1.0-1
- Bootstrap config package for CI mic builds
