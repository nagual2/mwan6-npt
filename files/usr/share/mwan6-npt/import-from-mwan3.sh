#!/bin/sh
# Import mwan3 IPv6 WAN interface names into mwan6-npt (add missing sections only).
# Does not overwrite existing mwan6-npt sections or lan/default settings.

CFG_DIR="${UCI_CONFIG_DIR:-/etc/config}"

[ -f "${CFG_DIR}/mwan3" ] || exit 0
[ -f "${CFG_DIR}/mwan6-npt" ] || exit 0

uci_query() {
	if [ "$CFG_DIR" != "/etc/config" ]; then
		uci -c "$CFG_DIR" "$@"
	else
		uci "$@"
	fi
}

IMPORTED=0

is_mwan3_iface_enabled() {
	local name="$1"
	local enabled family

	enabled=$(uci_query -q get "mwan3.${name}.enabled" 2>/dev/null) || return 1
	case "$enabled" in
		1 | true | yes | on) ;;
		*) return 1 ;;
	esac

	family=$(uci_query -q get "mwan3.${name}.family" 2>/dev/null)
	case "$family" in
		"" | ipv6) ;;
		ipv4) return 1 ;;
		*) return 1 ;;
	esac

	return 0
}

guess_wan_prefix() {
	local iface="$1"
	local prefix detected

	prefix=$(uci_query -q get "network.${iface}.ip6prefix" 2>/dev/null)
	if [ -n "$prefix" ]; then
		printf '%s\n' "$prefix"
		return 0
	fi

	if [ -x /usr/share/mwan6-npt/detect-wan-prefix.sh ]; then
		detected=$(/usr/share/mwan6-npt/detect-wan-prefix.sh "$iface" 2>/dev/null) || true
		if [ -n "$detected" ]; then
			printf '%s\n' "$detected"
			return 0
		fi
	fi

	return 1
}

for name in $(uci_query -X show mwan3 2>/dev/null | sed -n "s/^mwan3\.\([^=]*\)=interface\$/\1/p"); do
	[ "$name" = "lan" ] && continue
	is_mwan3_iface_enabled "$name" || continue
	uci_query -q get "mwan6-npt.${name}" >/dev/null 2>&1 && continue

	uci_query set "mwan6-npt.${name}=interface"
	uci_query set "mwan6-npt.${name}.enabled=1"
	uci_query set "mwan6-npt.${name}.default=0"

	prefix=$(guess_wan_prefix "$name" 2>/dev/null) || prefix=""
	[ -n "$prefix" ] && uci_query set "mwan6-npt.${name}.wan_prefix=${prefix}"

	IMPORTED=$((IMPORTED + 1))
	logger -t mwan6-npt "import-from-mwan3: added interface ${name}${prefix:+ prefix=${prefix}}"
done

[ "$IMPORTED" -gt 0 ] && uci_query commit mwan6-npt

exit 0
