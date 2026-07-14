Name:           pipa-qcom-userspace
Version:        1.0.0
Release:        1
Summary:        Qualcomm QRTR / PD mapper / TFTP / RMTFS for Xiaomi Pad 6
License:        BSD
URL:            https://github.com/linux-msm
Source0:        pipa-qcom-userspace.tar.gz

Requires:       xz
Requires:       systemd

%description
Qualcomm userspace services built against Sailfish OS glibc for mainline
Xiaomi Pad 6: libqrtr, pd-mapper, tqftpserv, and rmtfs (not enabled by default).

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/
# Drop host libdir duplicates; SFOS uses /usr/lib64 for aarch64
if [ -d %{buildroot}/usr/lib ] && [ -d %{buildroot}/usr/lib64 ]; then
  # prefer lib64 copies of shared libs; keep systemd under lib
  find %{buildroot}/usr/lib -maxdepth 1 -name 'libqrtr.so*' -delete || true
fi

%post
%systemd_post pd-mapper.service tqftpserv.service rmtfs.service || :
systemctl disable rmtfs.service >/dev/null 2>&1 || :
systemctl mask rmtfs.service >/dev/null 2>&1 || :

%preun
%systemd_preun pd-mapper.service tqftpserv.service rmtfs.service || :

%postun
%systemd_postun_with_restart pd-mapper.service tqftpserv.service || :
%systemd_postun rmtfs.service || :

%files
%defattr(-,root,root,-)
/usr/bin/pd-mapper
/usr/bin/tqftpserv
/usr/bin/rmtfs
/usr/bin/qrtr-lookup
/usr/lib64/libqrtr.so*
/usr/lib/systemd/system/pd-mapper.service
/usr/lib/systemd/system/tqftpserv.service
/usr/lib/systemd/system/rmtfs.service

%changelog
* Tue Jul 14 2026 Porter <porter@local> - 1.0.0-1
- Initial SFOS aarch64 package for pipa adaptation repo
