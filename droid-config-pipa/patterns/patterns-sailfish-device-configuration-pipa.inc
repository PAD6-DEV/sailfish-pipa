%package -n patterns-sailfish-device-configuration-pipa
Summary: Sailfish Configuration Xiaomi Pad 6 (pipa)

Requires: patterns-sailfish-device-configuration-common-pipa
Requires: patterns-sailfish-device-adaptation-pipa
Requires: patterns-sailfish-applications
Requires: patterns-sailfish-ui

# No cellular apps on tablet
#Requires: patterns-sailfish-cellular-apps

# Jolla Store Items
Requires: patterns-sailfish-consumer-generic
Requires: patterns-sailfish-store-applications

Requires: sailfish-content-graphics-z1.0
Requires: jolla-settings-accounts-extensions-3rd-party-all

# Online location (optional)
Requires: geoclue-provider-mlsdb

# CSD hardware testing
Requires: csd

Requires: kmod

# Porter / debug tools
Requires: jolla-developer-mode
Requires: jolla-rnd-device
Requires: sailfishsilica-qt5-demos
Requires: busybox-static
Requires: net-tools
Requires: openssh-clients
Requires: openssh-server
Requires: vim-enhanced
Requires: zypper
Requires: strace

Recommends: vi
Recommends: gdb
Recommends: mce-tools
Recommends: sailfishos-chum-gui

%description -n patterns-sailfish-device-configuration-pipa
Pattern with packages for Xiaomi Pad 6 (pipa) configurations

%files -n patterns-sailfish-device-configuration-pipa
