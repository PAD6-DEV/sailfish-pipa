Name:           plymouth-lite
Version:        0.6.0
Release:        3.pipa1
Summary:        Lightweight framebuffer boot splash
License:        GPL-2.0-only
URL:            https://github.com/sailfishos/plymouth-lite
Source0:        plymouth-lite.tar.gz

Requires:       systemd
Requires:       boot-splash-screen

%global __strip /bin/true
%global debug_package %{nil}

%description
Lightweight framebuffer splash program and systemd units from Sailfish OS.

%package theme-default
Summary:        Default images for plymouth-lite
BuildArch:      noarch
Provides:       boot-splash-screen

%description theme-default
Default Sailfish splash images used during boot, shutdown, and reboot.

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/

%post
systemctl daemon-reload >/dev/null 2>&1 || :

%postun
systemctl daemon-reload >/dev/null 2>&1 || :

%files
%defattr(-,root,root,-)
/usr/bin/ply-image
/usr/lib/systemd/system/plymouth-lite-start.service
/usr/lib/systemd/system/plymouth-lite-halt.service
/usr/lib/systemd/system/plymouth-lite-reboot.service
/usr/lib/systemd/system/plymouth-lite-poweroff.service
/usr/lib/systemd/system/sysinit.target.wants/plymouth-lite-start.service
/usr/lib/systemd/system/halt.target.wants/plymouth-lite-halt.service
/usr/lib/systemd/system/reboot.target.wants/plymouth-lite-reboot.service
/usr/lib/systemd/system/poweroff.target.wants/plymouth-lite-poweroff.service

%files theme-default
%defattr(-,root,root,-)
/usr/share/plymouth/splash.png
/usr/share/plymouth/halt.png
/usr/share/plymouth/reboot.png
/usr/share/plymouth/poweroff.png

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.6.0-3.pipa1
- Build Sailfish plymouth-lite and provide a self-contained default theme
