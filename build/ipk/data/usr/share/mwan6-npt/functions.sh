#!/bin/sh
# mwan6-npt helper functions

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
