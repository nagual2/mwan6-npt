#!/bin/sh
# Install mwan6-npt on OpenWrt 25.x (apk) from IPK without overwriting UCI config.
# Usage: ./install-tarball.sh <router_host>
#        SSH_KEY=~/.ssh/id_ed25519 ./install-tarball.sh 192.168.1.1
# Requires: ar, tar on build host; router reachable via scp/ssh.

set -e

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:?Usage: $0 <router_host>}"
IPK="${PKG_DIR}/dist/mwan6-npt_"*"_all.ipk"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_ed25519}"
STAGING="/tmp/mwan6-npt-install-$$"

IPK_FILE=$(ls -1 $IPK 2>/dev/null | tail -1)
[ -n "$IPK_FILE" ] || { echo "Build IPK first: make -f Makefile.build ipk"; exit 1; }

mkdir -p "$STAGING"
cd "$STAGING"
ar x "$IPK_FILE"
tar -xzf data.tar.gz
tar czf mwan6-npt-no-config.tar.gz usr etc/init.d etc/hotplug.d etc/uci-defaults

scp -O -i "$SSH_KEY" mwan6-npt-no-config.tar.gz "root@${HOST}:/tmp/"
ssh -i "$SSH_KEY" "root@${HOST}" '
    set -e
    mkdir -p /root/backup
    cp -a /etc/config/mwan6-npt /root/backup/mwan6-npt.$(date +%Y%m%d-%H%M).uci 2>/dev/null || true
    cd /
    tar -xzf /tmp/mwan6-npt-no-config.tar.gz
    chmod +x /etc/init.d/mwan6-npt /etc/hotplug.d/iface/25-mwan6-npt /usr/sbin/mwan6-npt
    chmod 644 /usr/share/mwan6-npt/functions.sh
    chown -R root:root /usr/share/mwan6-npt
    [ -x /etc/uci-defaults/99-mwan6-npt ] && /etc/uci-defaults/99-mwan6-npt || true
    /etc/init.d/mwan6-npt enable
    /usr/sbin/mwan6-npt update
    /usr/sbin/mwan6-npt status
'

rm -rf "$STAGING"
echo "Installed on $HOST (config preserved)"
