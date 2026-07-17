Name:           sensorfw-qt5-libssc
Version:        0.1.0
Release:        2
Summary:        sensorfw accelerometer adaptor using libssc (Qualcomm SSC)
License:        GPL-3.0-or-later
URL:            https://github.com/PAD6-DEV/sailfish-pipa
Source0:        sensorfw-qt5-libssc.tar.gz

Requires:       sensorfw-qt5
Requires:       libssc
Requires:       pipa-hexagonrpc

%global __strip /bin/true
%global debug_package %{nil}

%description
Sailfish Sensor Framework device adaptor that reads the Qualcomm Sensor Core
accelerometer through libssc. Enables orientationchain / screen rotation on
mainline Xiaomi Pad 6 (pipa).

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

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.0-2
- Force C linkage for libssc APIs (fix undefined C++-mangled symbols)
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.0-1
- Initial SSC accelerometer adaptor for sensorfw
