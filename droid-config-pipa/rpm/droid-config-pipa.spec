# Xiaomi Pad 6 (pipa) — Sailfish OS native mainline adaptation
# Structure adapted from sailfish-on-dontbeevil/droid-config-pinetab2

%define device pipa
%define vendor xiaomi

%define vendor_pretty Xiaomi
%define device_pretty Pad 6

# Community HW adaptations need this
%define community_adaptation 1

# Pad 6: 11" 1800x2880 — start with 1.5 and tune on device
%define pixel_ratio 1.5

%define native_build 1

# Device-specific usb-moded configuration (pinetab2 pattern)
Provides: usb-moded-configs
Obsoletes: usb-moded-defaults

%include droid-configs-device/droid-configs.inc
%include patterns/patterns-sailfish-device-adaptation-pipa.inc
%include patterns/patterns-sailfish-device-configuration-pipa.inc
