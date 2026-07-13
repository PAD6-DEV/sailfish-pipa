Name:           patterns-sailfish-device-configuration-pipa
Version:        0.1.0
Release:        1
Summary:        Sailfish configuration pattern for Xiaomi Pad 6
License:        BSD
BuildArch:      noarch

# Core UI / apps (from jolla repos)
Requires:       patterns-sailfish-ui
Requires:       patterns-sailfish-applications
Requires:       patterns-sailfish-consumer-generic

# Device adaptation bits available from native-common / jolla
Requires:       droid-config-pipa
Requires:       kernel-adaptation-pipa
Requires:       mesa-dri-drivers
Requires:       mesa-libEGL
Requires:       mesa-libGLESv2
Requires:       mesa-libgbm
Requires:       wayland-egl
Requires:       qt5-plugin-platform-eglfs
Requires:       qt5-qtwayland-wayland_egl
Requires:       pulseaudio-module-keepalive
Requires:       usb-moded
Requires:       jolla-developer-mode
Requires:       jolla-rnd-device
Requires:       openssh-server
Requires:       openssh-clients
Requires:       busybox-static
Requires:       zypper
Requires:       strace
Requires:       vim-enhanced
Requires:       net-tools
Requires:       kmod
Requires:       alsa-utils
Requires:       bluez5-tools
Requires:       jolla-devicelock-plugin-encsfa

%description
Bootstrap pattern so mic can assemble a Sailfish rootfs for pipa
before full droid-config OBS packaging is ready.

%files

%changelog
* Mon Jul 13 2026 Porter <porter@local> - 0.1.0-1
- Bootstrap pattern for CI
