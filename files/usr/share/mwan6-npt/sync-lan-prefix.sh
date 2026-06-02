#!/bin/sh
# Re-detect LAN NPT source prefix from network/ubus and update mwan6-npt.lan if found.
# Use after you configure PD/ip6prefix on lan (install-before-prefix case).

[ -f /etc/config/mwan6-npt ] || exit 1
uci -q get mwan6-npt.lan >/dev/null 2>&1 || exit 1

[ -x /usr/share/mwan6-npt/detect-lan-prefix.sh ] || exit 1

detected=$(/usr/share/mwan6-npt/detect-lan-prefix.sh 2>/dev/null) || detected=""
[ -n "$detected" ] || {
	echo "No LAN prefix detected (check network.lan ip6assign / ip6prefix / PD)" >&2
	exit 1
}

uci set mwan6-npt.lan.wan_prefix="$detected"
uci set mwan6-npt.lan.enabled='1'
uci set mwan6-npt.lan.default='1'
uci commit mwan6-npt

printf '%s\n' "$detected"
exit 0
