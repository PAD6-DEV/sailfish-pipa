Name:           patterns-sailfish-device-configuration-pipa
Version:        0.1.1
Release:        1
Summary:        Sailfish configuration pattern for Xiaomi Pad 6
License:        BSD
BuildArch:      noarch

Requires:       patterns-sailfish-ui
Requires:       patterns-sailfish-applications
Requires:       droid-config-pipa
Requires:       kernel-adaptation-pipa
Requires:       jolla-developer-mode
Requires:       jolla-rnd-device
Requires:       openssh-server
Requires:       openssh-clients
Requires:       busybox-static
Requires:       zypper
Requires:       kmod

%description
Bootstrap pattern for Xiaomi Pad 6 mic images. Avoids pulling
bleeding-edge native-common mesa that needs newer glibc than SFOS 5.0.

%files

%changelog
* Mon Jul 13 2026 Porter <porter@local> - 0.1.1-1
- Drop explicit mesa Requires to avoid glibc 2.38 conflict
