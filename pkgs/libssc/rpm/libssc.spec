Name:           libssc
Version:        0.4.4
Release:        2
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

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/
# Runtime only — drop headers / pkgconfig / gir / docs
rm -rf %{buildroot}/usr/include \
       %{buildroot}/usr/lib64/pkgconfig \
       %{buildroot}/usr/lib/pkgconfig \
       %{buildroot}/usr/share/gir-1.0 \
       %{buildroot}/usr/lib64/girepository-1.0 \
       %{buildroot}/usr/share/gtk-doc \
       %{buildroot}/usr/share/man \
       %{buildroot}/usr/share/bash-completion \
       %{buildroot}/usr/libexec/installed-tests || true
# Drop libqmi CLI helpers if present (keep shared libs + ssccli)
rm -f %{buildroot}/usr/bin/qmicli \
      %{buildroot}/usr/bin/qmi-firmware-update \
      %{buildroot}/usr/bin/qmi-network \
      %{buildroot}/usr/bin/qmi-proxy \
      %{buildroot}/usr/libexec/qmi-proxy || true

%files
%defattr(-,root,root,-)
/usr/bin/ssccli
/usr/lib64/libssc.so*
/usr/lib64/libqmi-glib.so*
/usr/lib64/libqrtr-glib.so*
/usr/lib64/libprotobuf-c.so*

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.4.4-2
- Drop unpackaged /usr/libexec/qmi-proxy from runtime package
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.4.4-1
- Initial SFOS aarch64 package for pipa (bundles qmi/qrtr/protobuf-c)
