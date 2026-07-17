Name:           sensorfw-qt5-libssc
Version:        0.1.0
Release:        3
Summary:        sensorfw SSC adaptors using libssc (accel + ALS)
License:        GPL-3.0-or-later
URL:            https://github.com/PAD6-DEV/sailfish-pipa
Source0:        sensorfw-qt5-libssc.tar.gz

Requires:       sensorfw-qt5
Requires:       libssc
Requires:       pipa-hexagonrpc

%global __strip /bin/true
%global debug_package %{nil}

%description
Sailfish Sensor Framework device adaptors that read Qualcomm Sensor Core
accelerometer and ambient light through libssc. Enables orientation /
screen rotation and MCE auto-brightness on mainline Xiaomi Pad 6 (pipa).

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/

%files
%defattr(-,root,root,-)
/usr/lib64/sensord-qt5/libsscaccelerometeradaptor-qt5.so
/usr/lib64/sensord-qt5/libsscalsadaptor-qt5.so

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.0-3
- Add SSC ambient light (ALS) adaptor for auto-brightness
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.0-2
- Force C linkage for libssc APIs (fix undefined C++-mangled symbols)
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.0-1
- Initial SSC accelerometer adaptor for sensorfw
