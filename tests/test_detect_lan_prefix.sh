#!/bin/sh
# Unit tests for detect-lan-prefix.sh (mock UCI/ubus)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
DETECT="$PKG_DIR/files/usr/share/mwan6-npt/detect-lan-prefix.sh"
TEST_ROOT="/tmp/mwan6-npt-detect-$$"

pass=0
fail=0

log_pass() { echo "[PASS] $1"; pass=$((pass + 1)); }
log_fail() { echo "[FAIL] $1"; fail=$((fail + 1)); }

cleanup() {
	rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

setup_uci_network() {
	mkdir -p "$TEST_ROOT/etc/config"
	cat >"$TEST_ROOT/etc/config/network" <<'EOF'
config interface 'lan'
	option proto 'static'

config interface 'tb62'
	option proto 'wireguard'
	list ip6prefix '2001:db8:1::/56'
EOF
}

run_detect() {
	UCI_CONFIG_DIR="$TEST_ROOT/etc/config" \
		"$DETECT" 2>/dev/null
}

test_reads_single_ip6prefix() {
	command -v uci >/dev/null 2>&1 || {
		echo "[SKIP] uci not available"
		return 0
	}

	setup_uci_network
	result=$(run_detect)
	if [ "$result" = "2001:db8:1::/56" ]; then
		log_pass "detect from network.ip6prefix"
	else
		log_fail "expected 2001:db8:1::/56, got: $result"
	fi
}

test_empty_without_sources() {
	command -v uci >/dev/null 2>&1 || {
		echo "[SKIP] uci not available"
		return 0
	}
	mkdir -p "$TEST_ROOT/etc/config"
	: >"$TEST_ROOT/etc/config/network"
	result=$(run_detect || true)
	if [ -z "$result" ]; then
		log_pass "empty when no prefix sources"
	else
		log_fail "expected empty, got: $result"
	fi
}

test_default_config_has_lan_only() {
	local cfg="$PKG_DIR/files/etc/config/mwan6-npt"
	local count

	count=$(grep -c "^config interface" "$cfg" || true)
	if [ "$count" -eq 1 ] && grep -q "config interface 'lan'" "$cfg"; then
		log_pass "default config contains lan only"
	else
		log_fail "default config should contain only lan section"
	fi

	if grep -q "option enabled '0'" "$cfg"; then
		log_pass "default config has globals.enabled=0"
	else
		log_fail "default config should disable service"
	fi
}

test_uci_defaults_no_update() {
	local script="$PKG_DIR/files/etc/uci-defaults/99-mwan6-npt"
	if grep -q 'mwan6-npt update' "$script"; then
		log_fail "uci-defaults must not run mwan6-npt update on install"
	else
		log_pass "uci-defaults skips rule generation on install"
	fi
}

main() {
	echo "=== detect-lan-prefix tests ==="
	test_default_config_has_lan_only
	test_uci_defaults_no_update
	test_reads_single_ip6prefix
	test_empty_without_sources
	echo "Results: $pass passed, $fail failed"
	[ "$fail" -eq 0 ]
}

main "$@"
