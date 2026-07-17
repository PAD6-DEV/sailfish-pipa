Name:           droid-config-pipa-policy-settings
Version:        0.1.5
Release:        1
Summary:        OHM policy settings for Xiaomi Pad 6 (pipa)
License:        BSD
BuildArch:      noarch
Source0:        policy-sparse.tar.gz

Provides:       droid-config-policy-settings
Provides:       ohm-configs > 1.1.15
Provides:       policy-settings
Obsoletes:      ohm-config <= 1.1.15
# ohm-configs-default should not be installed ever
Obsoletes:      ohm-configs-default
Conflicts:      ohm-configs-default

Requires:       ohm >= 1.1.16
Requires:       ohm-plugins-misc >= 1.2.0
Requires:       ohm-plugins-dbus
Requires:       ohm-plugin-telephony
Requires:       ohm-plugin-signaling
Requires:       ohm-plugin-media
Requires:       ohm-plugin-accessories
Requires:       ohm-plugin-resolver
Requires:       ohm-plugin-ruleengine
Requires:       ohm-plugin-profile
Requires:       ohm-plugin-route
Requires:       pulseaudio-modules-nemo-common >= 11.1.24
Requires:       pulseaudio-policy-enforcement >= 11.1.35
Requires:       policy-settings-common >= 0.7.3

%description
OHM resource-policy configuration for Xiaomi Pad 6 (volume keys / MainVolume).
Replaces stock ohm-configs-default.

%prep
%setup -q -c -n policy-sparse -T
tar -xzf %{SOURCE0} -C .

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
if [ -d policy-sparse ]; then
  cp -a policy-sparse/. %{buildroot}/
else
  cp -a . %{buildroot}/
  rm -f %{buildroot}/policy-sparse.tar.gz
fi

%files
%defattr(-,root,root,-)
/etc/ohm
/etc/dbus-1/system.d/ohm-policy.conf

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-1
- Bootstrap policy-settings: Obsolete ohm-configs-default; ship /etc/ohm
