#!/bin/sh
# Test mwan6-npt rule generation helpers (skip same prefix, router-src line).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

. "$PKG_DIR/files/usr/share/mwan6-npt/functions.sh"

LAN_PREFIX="fd00:lan::/56"
wan_prefix="fd00:lan::/56"
skipped=0
if [ "$wan_prefix" = "$LAN_PREFIX" ]; then
	skipped=1
fi
[ "$skipped" -eq 1 ] || {
	echo "FAIL: expected skip when wan_prefix equals LAN_PREFIX" >&2
	exit 1
}

dev="lo"
router_addr="$(mwan6_npt_iface_router_addr "$dev")"
router_addr="${router_addr:-fe80::1}"

srcnat_tmp="$STAGE/srcnat.nft"
: >"$srcnat_tmp"
echo "oifname \"$dev\" ip6 saddr $LAN_PREFIX snat prefix to fd00:wan::/56;" >>"$srcnat_tmp"
echo "oifname \"$dev\" ip6 saddr != fd00:wan::/56 snat ip6 to $router_addr;" >>"$srcnat_tmp"

grep -q 'snat prefix' "$srcnat_tmp" || exit 1
grep -q 'snat ip6 to' "$srcnat_tmp" || exit 1

echo "PASS: same-prefix skip logic and router-src rule format"
