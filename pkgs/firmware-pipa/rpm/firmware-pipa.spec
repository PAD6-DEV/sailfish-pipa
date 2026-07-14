Name:           firmware-pipa
Version:        20260714
Release:        2
Summary:        Xiaomi Pad 6 firmware (GPU, DSP, touch, WiFi, BT)
License:        Proprietary
Source0:        firmware-pipa-tree.tar.gz
BuildArch:      noarch

# DSP Hexagon blobs look like ELF to brp-strip; host strip cannot process them.
%global __strip /bin/true
%global __brp_strip_comment_note %{nil}
%global debug_package %{nil}

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
/lib

%changelog
* Tue Jul 14 2026 Porter <porter@local> - 20260714-2
- Skip host strip for Hexagon DSP firmware blobs
* Tue Jul 14 2026 Porter <porter@local> - 20260714-1
- Package pipa firmware tree as installable RPM
