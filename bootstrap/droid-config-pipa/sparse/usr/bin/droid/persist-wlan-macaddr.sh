#!/bin/sh

if [ -e /persist/wifi/.macaddr ] ; then
	echo "File /persist/wifi/.macaddr already exists"
	exit 0
fi

# ath11k may appear as wlan0 or wl*
iface=""
timeout=15
while [ "$timeout" -gt 0 ]; do
	for c in /sys/class/net/wlan0 /sys/class/net/wl*; do
		[ -e "$c" ] || continue
		iface=$(basename "$c")
		break
	done
	[ -n "$iface" ] && break
	sleep 1
	timeout=$((timeout - 1))
done

if [ -z "$iface" ]; then
	echo "Could not persist WiFi mac addr as the network interface isn't available"
	exit 0
fi

mkdir -p /persist/wifi
chmod 755 /persist/wifi
wifi_mac="$(cat < /sys/class/net/$iface/address)"
echo -ne "$wifi_mac" > /persist/wifi/.macaddr
