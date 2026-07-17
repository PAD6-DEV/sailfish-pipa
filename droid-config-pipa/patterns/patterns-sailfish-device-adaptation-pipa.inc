%package -n patterns-sailfish-device-adaptation-pipa
Summary: Sailfish HW Adaptation Xiaomi Pad 6 (pipa)

# evdev touch/keyboard/mouse are built into qt5-plugin-platform-eglfs on pipa
Obsoletes: qt5-plugin-generic-evdev

# Graphics — pipa freedreno Mesa (Provides mesa-libEGL / dri / gbm / GLES)
Requires: mesa-pipa
Requires: wayland-egl
Requires: qt5-plugin-platform-eglfs
Requires: mtdev

# Splash screen
Requires: plymouth-lite
Requires: plymouth-lite-theme-default

# Bluetooth tools
Requires: bluez5-tools

# Vibra
Requires: libngf-qt5-qtfeedback

# Sensors — mainline IIO path (not hybris)
#Requires: hybris-libsensorfw-qt5

# Pulseaudio — MainVolume / ringtone Settings need these modules
Requires: pulseaudio-module-keepalive
Requires: pulseaudio-modules-nemo-parameters
Requires: pulseaudio-policy-enforcement
Requires: policy-settings-common

# OHM resource policy (lipstick ScaleButton / volume keys / Qt Multimedia)
Requires: libdres
Requires: ohm-plugin-resolver
Requires: ohm-plugin-ruleengine
Requires: ohm-plugin-media
Requires: ohm-plugin-profile
Requires: ohm-plugin-accessories
Requires: ohm-plugin-signaling
Requires: ohm-plugin-telephony
Requires: ohm-plugins-dbus

# Connman
Requires: sailfish-connman-plugin-tethering-keepalive

# for audio recording to work:
Requires: qt5-qtmultimedia-plugin-mediaservice-gstmediacapture

# These need to be per-device due to differing backends (fbdev, eglfs, hwc, ..?)
Requires: qt5-qtwayland-wayland_egl
Requires: qtscenegraph-adaptation

# Add GStreamer v1.0 as standard
Requires: gstreamer1.0
Requires: gstreamer1.0-plugins-good
Requires: gstreamer1.0-plugins-base
Requires: gstreamer1.0-plugins-bad
Requires: nemo-gstreamer1.0-interfaces

# This is needed for notification LEDs / MCE backends
Requires: mce-plugin-libhybris

## USB mode controller
Requires: usb-moded

Requires: rfkill

# enable device lock and allow to select untrusted software
Requires: jolla-devicelock-plugin-encsfa

# sound
Requires: alsa-utils
Requires: alsa-ucm-conf

# Cameras
Requires: v4l-utils

# Firmware / regulatory
Requires: wireless-regdb
Requires: firmware-pipa

Requires: kernel-adaptation-pipa
Requires: droid-config-pipa-sailfish
Requires: droid-config-pipa-pulseaudio-settings
Requires: droid-config-pipa-policy-settings
Requires: droid-config-pipa-preinit-plugin
Requires: droid-config-pipa-bluez5
Requires: droid-hal-version-pipa

# Enable home encryption
Requires: sailfish-device-encryption-community

%description -n patterns-sailfish-device-adaptation-pipa
Pattern with packages for Xiaomi Pad 6 (pipa) HW Adaptation

%files -n patterns-sailfish-device-adaptation-pipa
