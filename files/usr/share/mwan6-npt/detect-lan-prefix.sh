#!/bin/sh
# Detect the LAN-side IPv6 prefix for mwan6-npt (read-only).
# Sources (first match wins):
#   1) Any non-ULA network.<iface>.ip6prefix (first global prefix found)
#   2) Delegated prefix on OpenWrt interface "lan" via ubus (ipv6-prefix-assignment)
# Does not modify UCI network. Re-run after PD setup: sync-lan-prefix.sh

is_ula_prefix() {
	case "$1" in
		fd*|fe80*) return 0 ;;
	esac
	return 1
}

uci_query() {
	if [ -n "${UCI_CONFIG_DIR:-}" ]; then
		uci -c "$UCI_CONFIG_DIR" "$@"
	else
		uci "$@"
	fi
}

detect_from_network_ip6prefix() {
	local section prefix found=""

	for section in $(uci_query -X show network 2>/dev/null | sed -n "s/^network\.\([^=]*\)=interface\$/\1/p"); do
		prefix=$(uci_query -q get "network.${section}.ip6prefix" 2>/dev/null)
		[ -n "$prefix" ] || continue
		is_ula_prefix "${prefix%%/*}" && continue
		if [ -n "$found" ] && [ "$found" != "$prefix" ]; then
			logger -t mwan6-npt "detect-lan-prefix: multiple network.ip6prefix values, using first"
			return 0
		fi
		found="$prefix"
	done

	[ -n "$found" ] || return 1
	printf '%s\n' "$found"
}

detect_from_lan_status() {
	local status prefix mask i=0

	command -v ubus >/dev/null 2>&1 || return 1
	command -v jsonfilter >/dev/null 2>&1 || return 1

	status=$(ubus call network.interface.lan status 2>/dev/null) || return 1
	[ -n "$status" ] || return 1

	while prefix=$(printf '%s' "$status" | jsonfilter -e "@['ipv6-prefix-assignment'][${i}].address" 2>/dev/null); do
		mask=$(printf '%s' "$status" | jsonfilter -e "@['ipv6-prefix-assignment'][${i}].mask" 2>/dev/null)
		i=$((i + 1))
		[ -n "$prefix" ] && [ -n "$mask" ] || continue
		is_ula_prefix "$prefix" && continue
		printf '%s/%s\n' "$prefix" "$mask"
		return 0
	done

	return 1
}

detect_from_network_ip6prefix || detect_from_lan_status
