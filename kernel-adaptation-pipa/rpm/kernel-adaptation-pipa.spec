Name:           kernel-adaptation-pipa
Version:        7.1.0
Release:        6
Summary:        Linux kernel for Xiaomi Pad 6 (Sailfish OS)
License:        GPL-2.0-only
URL:            https://github.com/PipaDB/linux/tree/pipa/7.1
Source0:        kernel-adaptation.tar.gz
BuildArch:      noarch
Provides:       kernel
# Drop any older placeholder package that only shipped a stub Image.
Obsoletes:      kernel-adaptation-pipa < 7.1.0

%global __strip /bin/true
%global debug_package %{nil}

%description
Kernel Image, DTBs, and modules for Xiaomi Pad 6 from PipaDB linux
pipa/7.1 (linux-pipa). Replaces the bootstrap placeholder RPM that
previously overwrote /boot/Image with a few-byte stub.

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/
# Hard fail if Image is missing or is still a placeholder.
test -s %{buildroot}/boot/Image
test $(stat -c%s %{buildroot}/boot/Image) -ge 1000000
# Arch linux-pipa also ships vmlinuz-*; U-Boot/Sailfish use Image — drop duplicates.
rm -f %{buildroot}/boot/vmlinuz-*

# filesystem owns /boot and /lib; never claim those directory nodes.
# List only payload paths (same pattern as droid-config-pipa).

%files
%defattr(-,root,root,-)
/boot/Image
/boot/Image.gz
/boot/System.map-*
/boot/config-*
/boot/dtbs
/lib/modules/*
/usr/share/kernel-adaptation-pipa

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 7.1.0-6
- Drop Arch vmlinuz-* duplicates so rpmbuild does not leave unpackaged files
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 7.1.0-5
- Pack linux-pipa 7.1.0-2 (builtin nt36532 + ktz8866)
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 7.1.0-4
- Do not own /boot (conflicts with filesystem); list payload paths only
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 7.1.0-3
- Fail staging if zstd modules remain; require panel .ko
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 7.1.0-2
- Decompress zstd modules so SFOS can load the nt36532 panel driver
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 7.1.0-1
- Ship real linux-pipa 7.1 Image/DTB/modules; obsolete placeholder package
* Mon Jul 13 2026 Sailfish pipa porter <porter@local> - 6.14.0-1
- Initial prebuilt packaging for Xiaomi Pad 6
