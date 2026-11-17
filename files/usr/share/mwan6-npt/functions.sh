#!/bin/sh
# mwan6-npt helper functions

# Normalize UCI boolean (handles quoted values and CRLF).
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

# Get interface primary global IPv6 address (WireGuard / tunnel endpoint).
mwan6_npt_iface_router_addr() {
    local dev="$1"

    ip -6 addr show dev "$dev" scope global 2>/dev/null \
        | awk '/inet6/ { print $2 }' | cut -d/ -f1 | head -1
}

# Live global prefix of a dynamic (RA/SLAAC) uplink device.
# Only addresses carrying the kernel 'dynamic' flag qualify: static tunnel
# endpoints (WireGuard/6in4) never have them, so their configured wan_prefix
# stays authoritative there. Needs an uncompressed 8-group address (no '::')
# and a prefix length that is a multiple of 16 (always true for SLAAC);
# anything else falls back to the configured wan_prefix.
mwan6_npt_iface_live_prefix() {
    local dev="$1"
    local full="" len="" live=""

    [ -n "$dev" ] || return 1
    full="$(ip -6 addr show dev "$dev" scope global 2>/dev/null \
        | awk '/inet6/ && /dynamic/ { print $2; exit }')"
    [ -n "$full" ] || return 1

    len="${full#*/}"
    case "$len" in '' | *[!0-9]*) return 1 ;; esac
    [ "$len" -gt 0 ] || return 1
    [ $((len % 16)) -eq 0 ] || return 1

    live="$(printf '%s' "${full%/*}" | awk -F: -v n="$((len / 16))" \
        'NF == 8 && n > 0 && $0 !~ /::/ { s = $1; for (i = 2; i <= n; i++) s = s ":" $i; print s "::"; exit }')"
    [ -n "$live" ] || return 1
    printf '%s/%s' "$live" "$len"
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
