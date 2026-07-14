Name:           firmware-pipa
Version:        20260714
Release:        1
Summary:        Xiaomi Pad 6 firmware (GPU, DSP, touch, WiFi, BT)
License:        Proprietary
Source0:        firmware-pipa-tree.tar.gz
BuildArch:      noarch

%description
Device firmware for Xiaomi Pad 6 mainline: Adreno, DSP hexagon FS,
touch, ath11k QCA6390, and QCA Bluetooth.

%prep
%setup -q -n destdir

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a . %{buildroot}/

%files
%defattr(-,root,root,-)
/usr/lib/firmware
/usr/share/qcom
# optional usr→lib firmware symlink from tarball
/lib

%changelog
* Tue Jul 14 2026 Porter <porter@local> - 20260714-1
- Package pipa firmware tree as installable RPM
