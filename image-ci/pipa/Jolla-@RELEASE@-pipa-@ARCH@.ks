# DisplayName: Jolla pipa/@ARCH@ (release)
# KickstartType: release
# SuggestedImageType: fs
# SuggestedArchitecture: aarch64
#
# Modeled on dont_be_evil-ci pinetab2 kickstart:
# https://gitlab.com/sailfishos-porters-ci/dont_be_evil-ci

timezone --utc UTC

part / --size 500 --ondisk sda --fstype=ext4

repo --name=adaptation-xiaomi-pipa-@RELEASE@ --baseurl=file:///parentroot/home/ayman/sailfish-pipa/repo/adaptation
repo --name=adaptation-community-common-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/devel:/hw:/common/sailfish_latest_@ARCH@/
repo --name=adaptation-native-common-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/devel:/hw:/native-common/sailfish_latest_@ARCH@/
repo --name=sailfishos-chum-@RELEASEMAJMIN@ --baseurl=http://repo.sailfishos.org/obs/sailfishos:/chum/@RELEASEMAJMIN@_@ARCH@/

repo --name=apps-@RELEASE@ --baseurl=https://releases.jolla.com/jolla-apps/@RELEASE@/@ARCH@/
repo --name=hotfixes-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/hotfixes/@ARCH@/
repo --name=jolla-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla/@ARCH@/

%packages
patterns-sailfish-device-configuration-pipa
%end

%pre
export SSU_RELEASE_TYPE=release
touch $INSTALL_ROOT/.bootstrap
%end

%post
export SSU_RELEASE_TYPE=release

echo -n "Rebuilding db using target rpm.."
rm -f /var/lib/rpm/__db*
rpm --rebuilddb
echo "done"

rm -f /.bootstrap
export LANG=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8
export GSETTINGS_BACKEND=gconf

UID_MIN=$(grep "^UID_MIN" /etc/login.defs |  tr -s " " | cut -d " " -f2)
DEVICEUSER=`getent passwd $UID_MIN | sed 's/:.*//'`

if [ -x /usr/bin/oneshot ]; then
   /usr/bin/oneshot --mic
   su -c "/usr/bin/oneshot --mic" $DEVICEUSER
fi

[ -n "@RELEASE@" ] && ssu release @RELEASE@
ssu mode 4

/usr/sbin/useradd -r -d / -s /sbin/nologin nfc || true
/usr/sbin/useradd -r -d / -s /sbin/nologin radio || true
getent group wheel >/dev/null || groupadd -g 10 wheel || true
if id nemo >/dev/null 2>&1; then
  usermod -aG wheel nemo || true
fi

# Ensure first user password is usable for session (not expired)
if [ -n "$DEVICEUSER" ]; then
  echo "${DEVICEUSER}:1234" | chpasswd || true
  TODAY=$(( $(date +%s) / 86400 ))
  if [ -f /etc/shadow ] && grep -q "^${DEVICEUSER}:" /etc/shadow; then
    awk -F: -v u="$DEVICEUSER" -v d="$TODAY" 'BEGIN{OFS=FS} $1==u{$3=d} {print}' /etc/shadow > /etc/shadow.new
    mv /etc/shadow.new /etc/shadow
    chmod 640 /etc/shadow
  fi
fi
%end

%post --nochroot
export SSU_RELEASE_TYPE=release
if [ -n "$IMG_NAME" ]; then
    echo "BUILD: $IMG_NAME" >> $INSTALL_ROOT/etc/meego-release
fi
%end
