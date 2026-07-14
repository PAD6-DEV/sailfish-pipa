#!/bin/sh
# Ensure USB debugging (sshd + accounts) after early boot / for sparse→image.
set -eu

mkdir -p /etc/ssh /etc/ssh/sshd_config.d /var/empty /run/sshd 2>/dev/null || true

# Drop Sailfish's AllowGroups lock — it blocks logins when defaultuser
# is not yet in sailfish-system (common on incomplete bring-up images).
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^AllowGroups /#AllowGroups /' /etc/ssh/sshd_config || true
fi

cat > /etc/ssh/sshd_config.d/99-pipa-debug.conf <<'EOF'
# Sailfish pipa USB debugging (SSH over RNDIS)
Port 22
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
ClientAliveInterval 30
ClientAliveCountMax 6
EOF

# Host keys (sshd will not start without them)
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -A 2>/dev/null || true
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' 2>/dev/null || true
    ssh-keygen -t rsa -b 2048 -f /etc/ssh/ssh_host_rsa_key -N '' 2>/dev/null || true
  fi
fi

# Create device owner if mic image omitted it
if ! id defaultuser >/dev/null 2>&1; then
  groupadd -g 100000 defaultuser 2>/dev/null || true
  useradd -m -u 100000 -g 100000 -s /bin/bash defaultuser 2>/dev/null \
    || useradd -m -u 100000 -s /bin/bash defaultuser 2>/dev/null || true
fi
# Groups used by SFOS features / ssh compatibility
for g in sailfish-system wheel audio video input; do
  groupadd "$g" 2>/dev/null || true
  usermod -aG "$g" defaultuser 2>/dev/null || true
done

# Fixed debug passwords (no forced aging)
PASS=1234
if command -v chpasswd >/dev/null 2>&1; then
  printf 'root:%s\ndefaultuser:%s\n' "$PASS" "$PASS" | chpasswd || true
elif command -v openssl >/dev/null 2>&1; then
  HASH=$(openssl passwd -6 "$PASS")
  for u in root defaultuser; do
    if grep -q "^${u}:" /etc/shadow 2>/dev/null; then
      sed -i "s|^${u}:[^:]*:|${u}:${HASH}:|" /etc/shadow || true
      # min/max/warn clear lastchg to today-ish and no expire
      awk -F: -v u="$u" -v h="$HASH" 'BEGIN{OFS=FS} $1==u{$2=h;$3=1;$4=0;$5=99999;$6=7;$7="";$8="";$9=""} {print}' \
        /etc/shadow > /etc/shadow.tmp && mv /etc/shadow.tmp /etc/shadow || true
    fi
  done
fi
# Strip password aging / force-change (IMPORTANT: never -d 0 — forces change)
TODAY=$(date +%Y-%m-%d 2>/dev/null || echo 2026-01-01)
for u in root defaultuser; do
  chage -d "$TODAY" -m 0 -M 99999 -I -1 -E -1 "$u" 2>/dev/null || true
  passwd -u "$u" 2>/dev/null || true
done

chmod 600 /etc/shadow 2>/dev/null || true
chmod 700 /root /home/defaultuser 2>/dev/null || true

systemctl enable sshd.service 2>/dev/null || true
systemctl enable sshd-keys.service 2>/dev/null || true
systemctl unmask sshd.service 2>/dev/null || true
systemctl mask usb-moded.service 2>/dev/null || true
systemctl stop usb-moded.service 2>/dev/null || true
systemctl restart sshd.service 2>/dev/null || /usr/sbin/sshd 2>/dev/null || true

exit 0
