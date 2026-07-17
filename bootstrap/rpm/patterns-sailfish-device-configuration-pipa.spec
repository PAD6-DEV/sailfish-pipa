Name:           patterns-sailfish-device-configuration-pipa
Version:        0.3.9
Release:        1
Summary:        Sailfish configuration pattern for Xiaomi Pad 6
License:        BSD
BuildArch:      noarch

# Mirror droid-config-pinetab2 configuration pattern (dont_be_evil-ci).
# Splash (yamuisplash) belongs on patterns-sailfish-device-adaptation-pipa
# (droid-config-pipa/patterns/patterns-sailfish-device-adaptation-pipa.inc).
Requires:       patterns-sailfish-ui
Requires:       patterns-sailfish-applications
Requires:       patterns-sailfish-consumer-generic
Requires:       patterns-sailfish-store-applications
Requires:       sailfish-content-graphics-z1.0
Requires:       jolla-settings-accounts-extensions-3rd-party-all
Requires:       geoclue-provider-mlsdb
Requires:       csd
Requires:       droid-config-pipa
Requires:       droid-config-pipa-pulseaudio-settings
Requires:       droid-config-pipa-policy-settings
Requires:       kernel-adaptation-pipa
Requires:       droid-hal-version-pipa
Requires:       mesa-pipa
Requires:       pipa-qcom-userspace
Requires:       pipa-hexagonrpc
Requires:       firmware-pipa
Requires:       alsa-utils
Requires:       jolla-developer-mode
Requires:       jolla-rnd-device
Requires:       sailfishsilica-qt5-demos
Requires:       busybox-static
Requires:       net-tools
Requires:       openssh-server
Requires:       openssh-clients
Requires:       vim-enhanced
Requires:       zypper
Requires:       strace
Requires:       kmod
Requires:       mtdev
Requires:       qt5-plugin-platform-eglfs
Recommends:     vi
Recommends:     sailfishos-chum-gui
Recommends:     mce-tools
Recommends:     gdb

%description
Bootstrap pattern for Xiaomi Pad 6 mic images — full UI/apps like
pinetab2 (dont_be_evil-ci). No UI force hacks; lipstick starts via
normal Sailfish session.

%files

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.3.9-1
- Require droid-config-pipa-policy-settings (replaces ohm-configs-default)
* Fri Jul 17 2026 Porter <porter@local> - 0.3.8-1
- Drop alsa-ucm-conf Requires (not in SFOS device repos; UCM is in droid-config)
* Fri Jul 17 2026 Porter <porter@local> - 0.3.7-1
- Align Recommends with pinetab2 (vi)
* Fri Jul 17 2026 Porter <porter@local> - 0.3.6-1
- Require droid-config-pipa-pulseaudio-settings for MainVolume tables
* Fri Jul 17 2026 Porter <porter@local> - 0.3.5-1
- Require droid-hal-version-pipa so images ship /etc/hw-release
* Thu Jul 16 2026 Porter <porter@local> - 0.3.4-1
- Pull alsa-utils and alsa-ucm-conf into mic images for native audio
* Thu Jul 16 2026 Porter <porter@local> - 0.3.3-1
- Require mesa-pipa so images install freedreno as an owned RPM
* Tue Jul 14 2026 Porter <porter@local> - 0.3.2-1
- Drop yamuisplash (owned by adaptation pattern .inc)
* Tue Jul 14 2026 Porter <porter@local> - 0.3.1-1
- Require yamuisplash for early boot splash
* Tue Jul 14 2026 Porter <porter@local> - 0.3.0-1
- Pull qcom userspace, hexagonrpc, and firmware-pipa from adaptation repo
* Mon Jul 13 2026 Porter <porter@local> - 0.2.0-1
- Align with pinetab2 full UI/apps pattern; drop hack-oriented Requires
* Mon Jul 13 2026 Porter <porter@local> - 0.1.2-1
- Add mtdev and eglfs for lipstick on mainline
* Mon Jul 13 2026 Porter <porter@local> - 0.1.1-1
- Drop explicit mesa Requires to avoid glibc 2.38 conflict
