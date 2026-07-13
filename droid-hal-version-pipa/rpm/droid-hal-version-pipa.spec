# rpm_device is the name of the ported device
%define rpm_device pipa
# rpm_vendor is used in the rpm space
%define rpm_vendor xiaomi
# Manufacturer and device name to be shown in UI
%define vendor_pretty Xiaomi
%define device_pretty Pad 6
%define have_ffmemless 1
%define native_build 1
%include droid-hal-version/droid-hal-version.inc
