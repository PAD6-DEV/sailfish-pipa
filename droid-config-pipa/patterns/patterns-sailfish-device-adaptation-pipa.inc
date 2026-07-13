%package -n patterns-sailfish-device-adaptation-pipa
Summary: Sailfish HW Adaptation Xiaomi Pad 6 (pipa)

# Evdev is built into the eglfs platform driver (pinetab2)
Obsoletes: qt5-plugin-generic-evdev

# Graphics (mesa + eglfs KMS — mainline, not hybris)
Requires: mesa-dri-drivers
Requires: mesa-libEGL
Requires: mesa-libGLESv2
Requires: mesa-libgbm
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

# Sensors — mainline path; hybris sensorfw not used
#Requires: hybris-libsensorfw-qt5

# Pulseaudio
Requires: pulseaudio-module-keepalive

# Connman
Requires: sailfish-connman-plugin-tethering-keepalive

# Audio recording
Requires: qt5-qtmultimedia-plugin-mediaservice-gstmediacapture

# Wayland / scenegraph
Requires: qt5-qtwayland-wayland_egl
Requires: qtscenegraph-adaptation

# GStreamer
Requires: gstreamer1.0
Requires: gstreamer1.0-plugins-good
Requires: gstreamer1.0-plugins-base
Requires: gstreamer1.0-plugins-bad
Requires: nemo-gstreamer1.0-interfaces

# Notification / display manager plugin
Requires: mce-plugin-libhybris

# USB mode controller
Requires: usb-moded

Requires: rfkill

# Device lock
Requires: jolla-devicelock-plugin-encsfa

# No cellular on tablet
#Requires: ofono

# sound
Requires: alsa-utils
Requires: alsa-ucm-conf

# Cameras
Requires: v4l-utils

Requires: kernel-adaptation-pipa
Requires: droid-config-pipa-sailfish
Requires: droid-config-pipa-pulseaudio-settings
Requires: droid-config-pipa-policy-settings
Requires: droid-config-pipa-preinit-plugin
Requires: droid-config-pipa-bluez5
Requires: droid-hal-version-pipa

Requires: sailfish-device-encryption-community

%description -n patterns-sailfish-device-adaptation-pipa
Pattern with packages for Xiaomi Pad 6 (pipa) HW Adaptation

%files -n patterns-sailfish-device-adaptation-pipa
