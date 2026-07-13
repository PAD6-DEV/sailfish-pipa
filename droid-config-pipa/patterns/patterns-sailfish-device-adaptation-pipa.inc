%package -n patterns-sailfish-device-adaptation-pipa
Summary: Sailfish HW Adaptation Xiaomi Pad 6 (pipa)

Requires: qt5-plugin-generic-evdev

# Graphics (mesa + eglfs KMS — mainline, not hybris)
Requires: mesa-dri-drivers
Requires: mesa-libEGL
Requires: mesa-libGLESv2
Requires: mesa-libgbm
Requires: mesa-libglapi
Requires: wayland-egl
Requires: qt5-plugin-platform-eglfs

# Splash screen
Requires: plymouth-lite
Requires: plymouth-lite-theme-default

# Bluetooth tools
Requires: bluez5-tools

# Vibra (if ffmemless available on kernel)
Requires: libngf-qt5-qtfeedback

# Sensors — mainline / SSC path; hybris sensorfw not used
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

# No cellular / ofono on tablet bring-up
#Requires: ofono

# sound
Requires: alsa-utils
Requires: alsa-ucm-conf

# Cameras (V4L2 / libcamera later)
Requires: v4l-utils

# Kernel + config packages produced by this adaptation
Requires: kernel-adaptation-pipa
Requires: droid-config-pipa-sailfish
Requires: droid-config-pipa-pulseaudio-settings
Requires: droid-config-pipa-policy-settings
Requires: droid-config-pipa-preinit-plugin
Requires: droid-config-pipa-bluez5
Requires: droid-hal-version-pipa

# Home encryption (community)
Requires: sailfish-device-encryption-community

# Developer / SSH reachability out of the box
Requires: openssh-server
Requires: openssh-clients

%description -n patterns-sailfish-device-adaptation-pipa
Pattern with packages for Xiaomi Pad 6 (pipa) HW Adaptation

%files -n patterns-sailfish-device-adaptation-pipa
