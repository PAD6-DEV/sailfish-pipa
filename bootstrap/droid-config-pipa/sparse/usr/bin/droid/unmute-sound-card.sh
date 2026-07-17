#!/bin/bash
# Ensure pipa ALSA/UCM card is unmuted and set as Pulse default (pinetab2 pattern).
CARD=0
SINK="alsa_output.0.HiFi___ucm0001.hw_X6_0__sink"
SOURCE="alsa_input.0.HiFi___ucm0001.hw_X6_2__source"

amixer -c "$CARD" sset Speaker unmute 2>/dev/null || true
amixer -c "$CARD" sset Speaker 100% 2>/dev/null || true

i=0
while ! pactl list sinks short 2>/dev/null | grep -q "$SINK"; do
	echo "Waiting for: $SINK"
	sleep 1
	i=$((i + 1))
	[ "$i" -ge 30 ] && exit 1
done
pactl set-default-sink "$SINK" 2>/dev/null || pacmd set-default-sink "$SINK"
pactl set-default-source "$SOURCE" 2>/dev/null || pacmd set-default-source "$SOURCE"
echo "Done"
