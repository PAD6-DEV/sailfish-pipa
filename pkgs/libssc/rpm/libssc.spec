Name:           libssc
Version:        0.4.4
Release:        4
Summary:        Qualcomm Sensor Core client library (and QMI/QRTR deps)
License:        GPL-3.0-or-later
URL:            https://codeberg.org/DylanVanAssche/libssc
Source0:        libssc.tar.gz

# Prebuilt aarch64 binaries; host brp-strip is x86 and must not run.
%global __strip /bin/true
%global debug_package %{nil}

%description
libssc exposes Qualcomm Sensor Core sensors over QRTR/QMI for mainline
Linux. This package also ships the runtime libraries it needs on Sailfish
(libqmi-glib, libqrtr-glib, libprotobuf-c) which are not in SFOS repos.

%package devel
Summary:        Development files for libssc
Requires:       %{name} = %{version}-%{release}

%description devel
Headers and pkg-config for building against libssc (e.g. sensorfw adaptors).

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/
# Drop unused bits from runtime tree
rm -rf %{buildroot}/usr/share/gir-1.0 \
       %{buildroot}/usr/lib64/girepository-1.0 \
       %{buildroot}/usr/share/gtk-doc \
       %{buildroot}/usr/share/man \
       %{buildroot}/usr/share/bash-completion \
       %{buildroot}/usr/libexec/installed-tests || true
rm -f %{buildroot}/usr/bin/qmicli \
      %{buildroot}/usr/bin/qmi-firmware-update \
      %{buildroot}/usr/bin/qmi-network \
      %{buildroot}/usr/bin/qmi-proxy \
      %{buildroot}/usr/libexec/qmi-proxy || true
# Prefer our simplified .pc (glib-only Requires) when present in the payload
if [ -f %{buildroot}/usr/share/libssc/libssc.pc ]; then
  install -Dm644 %{buildroot}/usr/share/libssc/libssc.pc \
    %{buildroot}/usr/lib64/pkgconfig/libssc.pc
  rm -rf %{buildroot}/usr/share/libssc
fi
# Drop other .pc files from bundled deps
if [ -d %{buildroot}/usr/lib64/pkgconfig ]; then
  find %{buildroot}/usr/lib64/pkgconfig -type f ! -name 'libssc.pc' -delete
fi
rm -rf %{buildroot}/usr/lib/pkgconfig || true
# Keep only libssc headers for -devel
if [ -d %{buildroot}/usr/include ]; then
  find %{buildroot}/usr/include -mindepth 1 -maxdepth 1 ! -name libssc -exec rm -rf {} +
fi

%files
%defattr(-,root,root,-)
/usr/bin/ssccli
/usr/lib64/libssc.so*
/usr/lib64/libqmi-glib.so*
/usr/lib64/libqrtr-glib.so*
/usr/lib64/libprotobuf-c.so*

%files devel
%defattr(-,root,root,-)
/usr/include/libssc
/usr/lib64/pkgconfig/libssc.pc

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.4.4-4
- Add G_BEGIN_DECLS to public sensor headers for C++ consumers
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.4.4-3
- Add libssc-devel for sensorfw adaptor builds
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.4.4-2
- Drop unpackaged /usr/libexec/qmi-proxy from runtime package
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.4.4-1
- Initial SFOS aarch64 package for pipa (bundles qmi/qrtr/protobuf-c)
