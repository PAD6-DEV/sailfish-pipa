Name:           droid-config-pipa
Version:        0.1.5
Release:        13
Summary:        Sailfish OS device config for Xiaomi Pad 6 (pipa)
License:        BSD
BuildArch:      noarch
Source0:        sparse.tar.gz

Requires:       openssh-server
Requires:       kmod
Requires:       usb-moded
# Ship UCM toplevel (ucm.conf); SFOS device images often lack alsa-ucm-conf.
Provides:       alsa-ucm-conf
Obsoletes:      alsa-ucm-conf
Conflicts:      alsa-ucm-conf

%description
Sparse overlays and services for Xiaomi Pad 6 Sailfish OS port.

%prep
%setup -q -c -n sparse -T
tar -xzf %{SOURCE0} -C .

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
if [ -d sparse ]; then
  cp -a sparse/. %{buildroot}/
else
  cp -a . %{buildroot}/
  rm -f %{buildroot}/sparse.tar.gz
fi
# filesystem owns /boot; only ship contents
rm -rf %{buildroot}/boot
mkdir -p %{buildroot}/boot/extlinux
if [ -f sparse/boot/extlinux/extlinux.conf ]; then
  cp -a sparse/boot/extlinux/extlinux.conf %{buildroot}/boot/extlinux/
elif [ -f boot/extlinux/extlinux.conf ]; then
  cp -a boot/extlinux/extlinux.conf %{buildroot}/boot/extlinux/
fi
# jolla-rnd-device owns usb-moded-args.conf; -r comes from systemd drop-in
rm -rf %{buildroot}/var/lib/environment/usb-moded
# Never ship jolla-camera.desktop — it is owned by jolla-camera. Wrap via trigger.
rm -f %{buildroot}/usr/share/applications/jolla-camera.desktop

# Do not package directory nodes owned by filesystem (/, /boot, /etc, …)
# List only payload prefixes so we never conflict on /boot itself.
# Services live under /usr/lib (pinetab pattern); no /lib payload.
%files
%defattr(-,root,root,-)
/boot/extlinux
/etc
/usr
/var
%exclude /etc/pulse
%exclude /etc/sysconfig/pulseaudio
%exclude /var/lib/nemo-pulseaudio-parameters
%exclude /etc/ohm
%exclude /etc/dbus-1/system.d/ohm-policy.conf

# Wrap Camera via jolla-camera-wrapper (env + libcamerify) without owning desktop.
%triggerin -- jolla-camera
DESKTOP=/usr/share/applications/jolla-camera.desktop
if [ -f "$DESKTOP" ] && ! grep -qF 'jolla-camera-wrapper' "$DESKTOP"; then
  sed -i 's|^Exec=.*|Exec=/usr/bin/invoker --type=silica-media,silica-qt5 -A -- /usr/bin/jolla-camera-wrapper|' "$DESKTOP" || :
fi

%posttrans
DESKTOP=/usr/share/applications/jolla-camera.desktop
if [ -f "$DESKTOP" ] && ! grep -qF 'jolla-camera-wrapper' "$DESKTOP"; then
  sed -i 's|^Exec=.*|Exec=/usr/bin/invoker --type=silica-media,silica-qt5 -A -- /usr/bin/jolla-camera-wrapper|' "$DESKTOP" || :
fi

%changelog
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-13
- Launch jolla-camera via wrappercamerabinsrc env wrapper (not bare libcamerify)
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-12
- Autoload panel-novatek-nt36532; restore verbose bootargs for display bringup
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-11
- Enable quiet/splash bootargs in extlinux for plymouth-lite
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-10
- Wrap jolla-camera via RPM trigger instead of conflicting .desktop file
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-9
- Point sensorfw at sscaccelerometeradaptor; wait for hexagonrpcd
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-8
- Mount Android persist for SSC sensor registry; stop forcing IIO sensorfw adaptors
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-7
- Restore ucm.conf/generic.conf so Pulse can open sm8250 UCM (null-sink fix)
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-6
- Add oneshot to clean broken SSU adaptation repo stubs on boot
* Fri Jul 17 2026 aymanrar2c <aymanrar2c@gmail.com> - 0.1.5-5
- Move OHM configs to droid-config-pipa-policy-settings (Obsolete ohm-configs-default)
* Fri Jul 17 2026 Porter <porter@local> - 0.1.5-4
- Ship HDMI_pipa.conf and point Xiaomi Pad 6 UCM at it; SSU adaptation repo keys
* Fri Jul 17 2026 Porter <porter@local> - 0.1.5-3
- Drop stock UCM files (HDMI.conf/ucm.conf/generic.conf) owned by alsa-ucm-conf
* Fri Jul 17 2026 Porter <porter@local> - 0.1.5-2
- Ship pulse config in droid-config-pipa-pulseaudio-settings subpackage
* Thu Jul 16 2026 Porter <porter@local> - 0.1.5-1
- Drop empty /lib from package (units under /usr/lib)
* Tue Jul 14 2026 Porter <porter@local> - 0.1.4-1
- Drop usb-moded-args.conf (conflicts with jolla-rnd-device; use systemd drop-in)
* Tue Jul 14 2026 Porter <porter@local> - 0.1.3-1
- WiFi/connman, UCM, multimedia v4l2src, SSU adaptation feature, QT services
* Mon Jul 13 2026 Porter <porter@local> - 0.1.2-1
- Avoid /boot directory conflict with filesystem package
* Mon Jul 13 2026 Porter <porter@local> - 0.1.1-1
- Minimal Requires for SFOS 5.0 mic
