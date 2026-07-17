Name:           droid-config-pipa-pulseaudio-settings
Version:        0.1.5
Release:        2
Summary:        PulseAudio settings for Xiaomi Pad 6 (pipa)
License:        BSD
BuildArch:      noarch
Source0:        pulse-sparse.tar.gz

Provides:       droid-config-pulseaudio-settings
Provides:       pulseaudio-settings
Requires:       pulseaudio >= 11.1+git4
Requires:       pulseaudio-modules-nemo-parameters >= 11.1.24
Requires:       pulseaudio-modules-nemo-stream-restore >= 11.1.24
Requires:       pulseaudio-modules-nemo-mainvolume >= 11.1.24
# native mainline (not hybris) — match droid-configs.inc %if native_build
Requires:       pulseaudio-module-keepalive
Requires:       pulseaudio-policy-enforcement >= 11.1.35

%description
PulseAudio configuration and MainVolume step tables for Xiaomi Pad 6.

%prep
%setup -q -c -n pulse-sparse -T
tar -xzf %{SOURCE0} -C .

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
if [ -d pulse-sparse ]; then
  cp -a pulse-sparse/. %{buildroot}/
else
  cp -a . %{buildroot}/
  rm -f %{buildroot}/pulse-sparse.tar.gz
fi

%files
%defattr(-,root,root,-)
/etc/pulse
/etc/sysconfig/pulseaudio
/var/lib/nemo-pulseaudio-parameters

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-2
- Native build: require pulseaudio-module-keepalive, not pulseaudio-modules-droid
* Fri Jul 17 2026 Porter <porter@local> - 0.1.5-1
- Bootstrap subpackage: pulse config + nemo-pulseaudio-parameters from device-common
