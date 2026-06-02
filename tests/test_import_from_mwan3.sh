#!/bin/sh
# Unit tests for import-from-mwan3.sh (mock UCI).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
IMPORT="$PKG_DIR/files/usr/share/mwan6-npt/import-from-mwan3.sh"
TEST_ROOT="/tmp/mwan6-npt-import-$$"
DOC_WAN="2001:db8:2::/56"

pass=0
fail=0

log_pass() { echo "[PASS] $1"; pass=$((pass + 1)); }
log_fail() { echo "[FAIL] $1"; fail=$((fail + 1)); }

cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

setup() {
	mkdir -p "$TEST_ROOT/etc/config"
	cat >"$TEST_ROOT/etc/config/mwan6-npt" <<'EOF'
config globals 'globals'
	option enabled '0'

config interface 'lan'
	option enabled '1'
	option default '1'
EOF
	cat >"$TEST_ROOT/etc/config/mwan3" <<'EOF'
config globals 'globals'
	option track_host_routes '1'

config interface 'tb62'
	option enabled '1'
	option family 'ipv6'

config interface 'wan'
	option enabled '1'
	option family 'ipv4'
EOF
	cat >"$TEST_ROOT/etc/config/network" <<EOF
config interface 'tb62'
	option proto 'wireguard'
	list ip6prefix '${DOC_WAN}'
EOF
}

run_import() {
	UCI_CONFIG_DIR="$TEST_ROOT/etc/config" "$IMPORT" 2>/dev/null
}

test_imports_ipv6_enabled_only() {
	command -v uci >/dev/null 2>&1 || {
		echo "[SKIP] uci not available"
		return 0
	}
	setup
	run_import
	uci -c "$TEST_ROOT/etc/config" -q get mwan6-npt.tb62 >/dev/null 2>&1 || {
		log_fail "tb62 section not created"
		return
	}
	uci -c "$TEST_ROOT/etc/config" -q get mwan6-npt.wan >/dev/null 2>&1 && {
		log_fail "ipv4-only mwan3 interface wan must not be imported"
		return
	}
	prefix=$(uci -c "$TEST_ROOT/etc/config" -q get mwan6-npt.tb62.wan_prefix 2>/dev/null)
	if [ "$prefix" = "$DOC_WAN" ]; then
		log_pass "imported tb62 with network ip6prefix"
	else
		log_fail "expected wan_prefix $DOC_WAN, got: $prefix"
	fi
}

test_skips_existing_section() {
	command -v uci >/dev/null 2>&1 || {
		echo "[SKIP] uci not available"
		return 0
	}
	setup
	echo "config interface 'tb62'" >>"$TEST_ROOT/etc/config/mwan6-npt"
	echo "	option enabled '0'" >>"$TEST_ROOT/etc/config/mwan6-npt"
	echo "	option wan_prefix '2001:db8:99::/56'" >>"$TEST_ROOT/etc/config/mwan6-npt"
	run_import
	prefix=$(uci -c "$TEST_ROOT/etc/config" -q get mwan6-npt.tb62.wan_prefix 2>/dev/null)
	if [ "$prefix" = "2001:db8:99::/56" ]; then
		log_pass "does not overwrite existing mwan6-npt section"
	else
		log_fail "existing tb62.wan_prefix was changed"
	fi
}

main() {
	echo "=== import-from-mwan3 tests ==="
	test_imports_ipv6_enabled_only
	test_skips_existing_section
	echo "Results: $pass passed, $fail failed"
	[ "$fail" -eq 0 ]
}

main "$@"
