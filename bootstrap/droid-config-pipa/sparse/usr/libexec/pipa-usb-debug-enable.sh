#!/bin/sh
# Prepare SSH accounts/config for USB debugging.
# CRITICAL: never call blocking systemctl start/restart/enable here during
# early boot — that deadlocks when this unit is Before=sshd/multi-user.
set +e

mkdir -p /etc/ssh /etc/ssh/sshd_config.d /var/empty /run/sshd 2>/dev/null

# Drop Sailfish AllowGroups lock (blocks login when group has no owners yet).
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^AllowGroups /#AllowGroups /' /etc/ssh/sshd_config
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

# Host keys only if missing (non-blocking).
if [ ! -f /etc/ssh/ssh_host_ed25519_key ] && command -v ssh-keygen >/dev/null 2>&1; then
  ssh-keygen -A >/dev/null 2>&1
  [ -f /etc/ssh/ssh_host_ed25519_key ] || \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' >/dev/null 2>&1
  [ -f /etc/ssh/ssh_host_rsa_key ] || \
    ssh-keygen -t rsa -b 2048 -f /etc/ssh/ssh_host_rsa_key -N '' >/dev/null 2>&1
fi

# Create device owner if image omitted it.
if ! id defaultuser >/dev/null 2>&1; then
  groupadd -g 100000 defaultuser 2>/dev/null
  useradd -m -u 100000 -g 100000 -s /bin/bash defaultuser 2>/dev/null \
    || useradd -m -u 100000 -s /bin/bash defaultuser 2>/dev/null
fi
for g in sailfish-system wheel audio video input; do
  groupadd "$g" 2>/dev/null
  usermod -aG "$g" defaultuser 2>/dev/null
done

# Passwords for bring-up (skip if chpasswd unavailable).
PASS=1234
if command -v chpasswd >/dev/null 2>&1; then
  printf 'root:%s\ndefaultuser:%s\n' "$PASS" "$PASS" | chpasswd
fi
TODAY=$(date +%Y-%m-%d 2>/dev/null || echo 2026-01-01)
for u in root defaultuser; do
  chage -d "$TODAY" -m 0 -M 99999 -I -1 -E -1 "$u" 2>/dev/null
  passwd -u "$u" 2>/dev/null
done

chmod 600 /etc/shadow 2>/dev/null
chmod 700 /root /home/defaultuser 2>/dev/null

# Only create enablement symlinks — do NOT systemctl start/restart/enable
# (dbus call can deadlock early boot).
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sfn /usr/lib/systemd/system/sshd.service \
  /etc/systemd/system/multi-user.target.wants/sshd.service 2>/dev/null
ln -sfn /dev/null /etc/systemd/system/usb-moded.service 2>/dev/null

exit 0
