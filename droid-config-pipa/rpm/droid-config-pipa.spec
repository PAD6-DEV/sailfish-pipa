# Xiaomi Pad 6 (pipa) — Sailfish OS native mainline adaptation
# Structure follows sailfish-on-dontbeevil (pinetab/pinephone).

%define device pipa
%define vendor xiaomi

%define vendor_pretty Xiaomi
%define device_pretty Pad 6

# Community HW adaptations need this
%define community_adaptation 1

# Pad 6: 11" 1800x2880 — start with 1.5 and tune on device
%define pixel_ratio 1.5

%define native_build 1

%include droid-configs-device/droid-configs.inc
%include patterns/patterns-sailfish-device-adaptation-pipa.inc
%include patterns/patterns-sailfish-device-configuration-pipa.inc
