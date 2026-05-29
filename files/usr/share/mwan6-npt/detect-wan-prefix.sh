#!/bin/sh
# Suggest WAN-side NPT prefix from interface addresses (read-only).
# Does not read network.ip6prefix (reserved for single LAN PD source).
# Usage: detect-wan-prefix.sh <interface>

iface="${1:?interface name required}"

is_ula_addr() {
	case "$1" in
		fd*|fe80*) return 0 ;;
	esac
	return 1
}

command -v ubus >/dev/null 2>&1 || exit 1
command -v jsonfilter >/dev/null 2>&1 || exit 1

status=$(ubus call "network.interface.${iface}" status 2>/dev/null) || exit 1
[ -n "$status" ] || exit 1

i=0
while addr=$(printf '%s' "$status" | jsonfilter -e "@['ipv6-address'][${i}].address" 2>/dev/null); do
	mask=$(printf '%s' "$status" | jsonfilter -e "@['ipv6-address'][${i}].mask" 2>/dev/null)
	i=$((i + 1))
	[ -n "$addr" ] && [ -n "$mask" ] || continue
	is_ula_addr "$addr" && continue
	printf '%s/%s\n' "$addr" "$mask"
	exit 0
done

exit 1
