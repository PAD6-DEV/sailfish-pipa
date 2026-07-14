Name:           pipa-hexagonrpc
Version:        0.3.2
Release:        3
Summary:        FastRPC / hexagonrpcd for Xiaomi Pad 6 sensors DSP
License:        GPL-3.0-or-later
URL:            https://github.com/linux-msm/hexagonrpc
Source0:        pipa-hexagonrpc.tar.gz

Requires:       systemd

# Prebuilt aarch64 binaries; host brp-strip is x86 and must not run.
%global __strip /bin/true
%global debug_package %{nil}

%description
hexagonrpcd and libhexagonrpc built for Sailfish OS aarch64 (Xiaomi Pad 6).

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/
rm -rf %{buildroot}/usr/include %{buildroot}/usr/lib64/pkgconfig %{buildroot}/usr/lib/pkgconfig || true

%pre
getent group fastrpc >/dev/null || groupadd -r fastrpc || :
getent passwd fastrpc >/dev/null || \
  useradd -r -g fastrpc -d /var/lib/fastrpc -s /sbin/nologin -c FastRPC fastrpc || :
mkdir -p /var/lib/fastrpc || :

%post
%systemd_post hexagonrpcd-sdsp.service || :
systemctl disable hexagonrpcd-adsp-rootpd.service >/dev/null 2>&1 || :
systemctl mask hexagonrpcd-adsp-rootpd.service >/dev/null 2>&1 || :

%preun
%systemd_preun hexagonrpcd-sdsp.service || :

%postun
%systemd_postun_with_restart hexagonrpcd-sdsp.service || :

%files
%defattr(-,root,root,-)
/usr/bin/hexagonrpcd
/usr/lib64/libhexagonrpc.so*
/usr/libexec/hexagonrpc
/usr/lib/systemd/system/hexagonrpcd-sdsp.service
/usr/lib/systemd/system/hexagonrpcd-adsp-rootpd.service
/usr/lib/systemd/system/hexagonrpcd-adsp-sensorspd.service
/usr/lib/sysusers.d/fastrpc.conf
/usr/lib/udev/rules.d/10-fastrpc.rules

%changelog
* Tue Jul 14 2026 Porter <porter@local> - 0.3.2-3
- Vendor misc/fastrpc.h UAPI for SFOS SDK builds
* Tue Jul 14 2026 Porter <porter@local> - 0.3.2-2
- Skip host strip for aarch64 binaries
* Tue Jul 14 2026 Porter <porter@local> - 0.3.2-1
- Initial SFOS aarch64 package for pipa adaptation repo
