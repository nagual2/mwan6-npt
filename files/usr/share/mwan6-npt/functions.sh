#!/bin/sh
# mwan6-npt helper functions

# Normalize UCI boolean (handles quoted values like '\''0'\'').
mwan6_npt_is_true() {
    local v="${1:-0}"

    v="$(printf '%s' "$v" | tr -d "'\" \t\r\n")"
    case "$v" in
        1 | true | yes | on) return 0 ;;
    esac
    return 1
}

# Resolve logical OpenWrt interface name to kernel device (e.g. henet -> 6in4-henet).
mwan6_npt_iface_device() {
    local logical="$1"
    local dev=""

    if command -v jsonfilter >/dev/null 2>&1; then
        dev="$(ubus call "network.interface.${logical}" status 2>/dev/null \
            | jsonfilter -e '@.l3_device' 2>/dev/null)"
    fi
    if [ -z "$dev" ]; then
        dev="$(uci -q get "network.${logical}.ifname")"
    fi
    if [ -z "$dev" ] && ip link show "$logical" >/dev/null 2>&1; then
        dev="$logical"
    fi
    printf '%s' "$dev"
}

# True when link is usable for egress (WireGuard, 6in4/SIT, etc.).
mwan6_npt_iface_up() {
    local dev="$1"

    [ -n "$dev" ] || return 1
    ip link show "$dev" 2>/dev/null | grep -qE 'LOWER_UP|state UP'
}

# Check if interface has IPv6 connectivity
mwan6_npt_check_connectivity() {
    local iface="$1"
    local test_host="${2:-2001:4860:4860::8888}"

    ip -6 route get "$test_host" from "$LAN_PREFIX" iif "$iface" >/dev/null 2>&1
}

# Get interface IPv6 prefix from routing table
mwan6_npt_get_prefix() {
    local iface="$1"
    ip -6 route show dev "$iface" 2>/dev/null | awk '/^[0-9a-f]+:/ {print $1; exit}'
}

# Validate IPv6 prefix format
mwan6_npt_validate_prefix() {
    local prefix="$1"
    echo "$prefix" | grep -qE '^[0-9a-fA-F:]+::/[0-9]+$'
}

# Log with level
mwan6_npt_log() {
    local level="$1"
    local msg="$2"
    logger -t "mwan6-npt[$level]" "$msg"
}
