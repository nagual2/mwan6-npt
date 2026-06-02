#!/bin/sh
# Install or upgrade mwan6-npt via apk on OpenWrt 25.12+ (preserves /etc/config/mwan6-npt).
# Usage: ./scripts/install-apk.sh <router_host>
set -eu

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:?Usage: $0 <router_host>}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_ed25519}"
APK_FILE="$(ls -1 "$PKG_DIR"/dist/mwan6-npt-*.apk 2>/dev/null | tail -1)"

[ -n "$APK_FILE" ] || {
	echo "Build APK first: make -f Makefile.build apk" >&2
	exit 1
}

BASENAME="$(basename "$APK_FILE")"
REMOTE="/tmp/$BASENAME"

echo "Backing up mwan6-npt UCI on $HOST..."
ssh -i "$SSH_KEY" "root@${HOST}" '
	set -e
	B="/root/backup/apk-install-$(date +%Y%m%d-%H%M%S)"
	mkdir -p "$B"
	[ -f /etc/config/mwan6-npt ] && cp -a /etc/config/mwan6-npt "$B/"
	echo "Backup: $B"
'

echo "Removing stock/manual mwan6-npt..."
ssh -i "$SSH_KEY" "root@${HOST}" '
	set -e
	if apk info -e mwan6-npt >/dev/null 2>&1; then
		apk del mwan6-npt
	fi
'

echo "Installing $BASENAME via apk..."
scp -O -i "$SSH_KEY" "$APK_FILE" "root@${HOST}:${REMOTE}"
ssh -i "$SSH_KEY" "root@${HOST}" "
	set -e
	apk add --allow-untrusted --force-overwrite '${REMOTE}'
	rm -f '${REMOTE}'
	[ -x /etc/uci-defaults/99-mwan6-npt ] && sh /etc/uci-defaults/99-mwan6-npt || true
	/etc/init.d/mwan6-npt enable
	/usr/sbin/mwan6-npt update
	chown -R root:root /usr/sbin/mwan6-npt /usr/share/mwan6-npt /etc/init.d/mwan6-npt 2>/dev/null || true
	apk info -e mwan6-npt
	ls -la /usr/sbin/mwan6-npt /usr/share/mwan6-npt/functions.sh
	find /usr/share/mwan6-npt /etc/init.d/mwan6-npt -user 1000 2>/dev/null | head -3 || echo 'OK: no uid 1000 on mwan6-npt files'
	/usr/sbin/mwan6-npt status | head -8
"

echo "Installed mwan6-npt on $HOST"
echo "Pin check:"
ssh -i "$SSH_KEY" "root@${HOST}" "grep '^mwan6-npt><' /etc/apk/world || echo 'WARN: mwan6-npt not pinned'"
