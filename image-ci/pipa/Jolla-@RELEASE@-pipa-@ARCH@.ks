# DisplayName: Jolla pipa/@ARCH@ (release)
# KickstartType: release
# SuggestedImageType: fs
# SuggestedArchitecture: aarch64

timezone --utc UTC

part / --size 500 --ondisk sda --fstype=ext4

# Local adaptation repo (file:// mounted into SDK) — override via LOCAL_REPO_URL
repo --name=adaptation-xiaomi-pipa-@RELEASE@ --baseurl=file:///parentroot/home/ayman/sailfish-pipa/repo/adaptation
repo --name=adaptation-community-common-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/devel:/hw:/common/sailfish_latest_@ARCH@/
repo --name=adaptation-community-native-common-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/devel:/hw:/native-common/sailfish_latest_@ARCH@/
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

if [ "@ARCH@" == armv7hl ] || [ "@ARCH@" == armv7tnhl ]; then
    echo -n "@ARCH@-meego-linux" > /etc/rpm/platform
    echo "arch = @ARCH@" >> /etc/zypp/zypp.conf
fi

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

if [ "$SSU_RELEASE_TYPE" = "rnd" ]; then
    [ -n "@RNDRELEASE@" ] && ssu release -r @RNDRELEASE@
    [ -n "@RNDFLAVOUR@" ] && ssu flavour @RNDFLAVOUR@
    [ -n "@RELEASE@" ] && ssu set update-version @RELEASE@
    ssu mode 2
else
    [ -n "@RELEASE@" ] && ssu release @RELEASE@
    ssu mode 4
fi

export SSU_DOMAIN=@RNDFLAVOUR@
if [ "$SSU_RELEASE_TYPE" = "release" ] && [[ "$SSU_DOMAIN" = "public-sdk" ]]; then
    ssu domain sailfish
fi

/usr/sbin/useradd -r -d / -s /sbin/nologin nfc || true
/usr/sbin/useradd -r -d / -s /sbin/nologin radio || true

# Ensure wheel exists for nemo-devicelock socket group
getent group wheel >/dev/null || groupadd -g 10 wheel || true
# Default SFOS user is typically nemo uid 100000
if id nemo >/dev/null 2>&1; then
  usermod -aG wheel nemo || true
fi

%end

%post --nochroot
export SSU_RELEASE_TYPE=release
if [ -n "$IMG_NAME" ]; then
    echo "BUILD: $IMG_NAME" >> $INSTALL_ROOT/etc/meego-release
fi
%end
