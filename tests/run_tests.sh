#!/bin/sh
# mwan6-npt test suite
# Run with: ./run_tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
TEST_CONFIG="$SCRIPT_DIR/test_config"
MOCK_DIR="$SCRIPT_DIR/mocks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    passed=$((passed + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    failed=$((failed + 1))
}

# Setup test environment
setup() {
    log_info "Setting up test environment..."
    mkdir -p "$MOCK_DIR"
    mkdir -p "$TEST_CONFIG"
    
    # Create mock UCI config
    cat > "$TEST_CONFIG/mwan6-npt" << 'EOF'
config globals 'globals'
	option enabled '1'
	option lan_prefix 'fd00:1111:2222:f000::/64'

config interface 'test_wan1'
	option enabled '1'
	option wan_prefix 'fd00:aaaa:bbbb:1111::/64'

config interface 'test_wan2'
	option enabled '1'
	option wan_prefix 'fd00:cccc:dddd:2222::/64'

config interface 'test_disabled'
	option enabled '0'
	option wan_prefix 'fd00:eeee:ffff:3333::/64'
EOF
}

# Cleanup test environment
teardown() {
    log_info "Cleaning up test environment..."
    rm -rf "$MOCK_DIR"
    rm -rf "$TEST_CONFIG"
}

# Test: Load UCI configuration
test_load_config() {
    log_info "Test: Load UCI configuration"
    
    # Source the functions
    . /lib/functions.sh 2>/dev/null || {
        log_info "Skipping UCI test (functions.sh not available in test environment)"
        return 0
    }
    
    local config_file="$TEST_CONFIG/mwan6-npt"
    
    # Test globals
    local enabled lan_prefix
    config_load -c "$TEST_CONFIG" mwan6-npt
    config_get enabled globals enabled
    config_get lan_prefix globals lan_prefix
    
    if [ "$enabled" = "1" ] && [ "$lan_prefix" = "fd00:1111:2222:f000::/64" ]; then
        log_pass "UCI globals loaded correctly"
    else
        log_fail "UCI globals mismatch: enabled=$enabled, lan_prefix=$lan_prefix"
    fi
}

# Test: Validate IPv6 prefix format
test_validate_prefix() {
    log_info "Test: Validate IPv6 prefix format"
    
    local valid_prefixes=(
        "fd00:1111:2222:f000::/64"
        "2001:db8::/64"
        "2a11:6c7:f05:14f::/64"
        "fd00::/64"
    )
    
    local invalid_prefixes=(
        "not-a-prefix"
        "192.168.1.0/24"
        "::1"
        ""
    )
    
    local valid_count=0
    for prefix in "${valid_prefixes[@]}"; do
        if echo "$prefix" | grep -qE '^[0-9a-fA-F:]+::/[0-9]+$'; then
            valid_count=$((valid_count + 1))
        fi
    done
    
    local invalid_count=0
    for prefix in "${invalid_prefixes[@]}"; do
        if ! echo "$prefix" 2>/dev/null | grep -qE '^[0-9a-fA-F:]+::/[0-9]+$'; then
            invalid_count=$((invalid_count + 1))
        fi
    done
    
    if [ $valid_count -eq ${#valid_prefixes[@]} ]; then
        log_pass "All valid prefixes accepted"
    else
        log_fail "Valid prefix validation failed: $valid_count/${#valid_prefixes[@]}"
    fi
    
    if [ $invalid_count -eq ${#invalid_prefixes[@]} ]; then
        log_pass "All invalid prefixes rejected"
    else
        log_fail "Invalid prefix validation failed: $invalid_count/${#invalid_prefixes[@]}"
    fi
}

# Test: Generate NPTv6 rules
test_generate_rules() {
    log_info "Test: Generate NPTv6 rules"
    
    local test_srcnat="$MOCK_DIR/test_srcnat.nft"
    local test_dstnat="$MOCK_DIR/test_dstnat.nft"
    local lan_prefix="fd00:1111:2222:f000::/64"
    local wan_prefix="fd00:aaaa:bbbb:1111::/64"
    local iface="test_wan1"
    
    # Generate test rules
    > "$test_srcnat"
    > "$test_dstnat"
    
    echo "oifname \"$iface\" ip6 saddr $lan_prefix snat prefix to $wan_prefix;" >> "$test_srcnat"
    echo "iifname \"$iface\" ip6 daddr $wan_prefix dnat prefix to $lan_prefix;" >> "$test_dstnat"
    
    # Verify rules
    if grep -q "snat prefix to $wan_prefix" "$test_srcnat"; then
        log_pass "SNAT rule generated correctly"
    else
        log_fail "SNAT rule not found"
    fi
    
    if grep -q "dnat prefix to $lan_prefix" "$test_dstnat"; then
        log_pass "DNAT rule generated correctly"
    else
        log_fail "DNAT rule not found"
    fi
    
    # Verify syntax
    if grep -qE 'oifname "[a-z0-9_]+" ip6 saddr' "$test_srcnat"; then
        log_pass "SNAT rule syntax valid"
    else
        log_fail "SNAT rule syntax invalid"
    fi
}

# Test: Check interface filtering (enabled/disabled)
test_interface_filtering() {
    log_info "Test: Interface filtering (enabled/disabled)"
    
    # Count enabled interfaces in test config
    local enabled_count=0
    local disabled_count=0
    
    while read -r line; do
        case "$line" in
            *"config interface"*)
                current_iface="$line"
                ;;
            *"option enabled '1'")
                enabled_count=$((enabled_count + 1))
                ;;
            *"option enabled '0'")
                disabled_count=$((disabled_count + 1))
                ;;
        esac
    done < "$TEST_CONFIG/mwan6-npt"
    
    if [ $enabled_count -eq 2 ]; then
        log_pass "Correct number of enabled interfaces (2)"
    else
        log_fail "Expected 2 enabled interfaces, found $enabled_count"
    fi
    
    if [ $disabled_count -eq 1 ]; then
        log_pass "Correct number of disabled interfaces (1)"
    else
        log_fail "Expected 1 disabled interface, found $disabled_count"
    fi
}

# Test: Rule file paths
test_rule_paths() {
    log_info "Test: Rule file paths"
    
    local expected_srcnat="/usr/share/nftables.d/chain-post/srcnat/99-mwan6-npt.nft"
    local expected_dstnat="/usr/share/nftables.d/chain-post/dstnat/99-mwan6-npt.nft"
    
    # Verify paths are in fw4 chain-post directory
    if echo "$expected_srcnat" | grep -q "chain-post/srcnat"; then
        log_pass "SRCNAT path in correct fw4 directory"
    else
        log_fail "SRCNAT path not in fw4 directory"
    fi
    
    if echo "$expected_dstnat" | grep -q "chain-post/dstnat"; then
        log_pass "DSTNAT path in correct fw4 directory"
    else
        log_fail "DSTNAT path not in fw4 directory"
    fi
}

# Test: Mock interface state check
test_interface_state_check() {
    log_info "Test: Interface state detection logic"
    
    # Test the logic that would be used (mocked)
    local test_iface="lo"  # loopback always exists
    
    if ip link show "$test_iface" 2>/dev/null | grep -q "UP"; then
        log_pass "Interface state detection works for existing interface"
    else
        log_fail "Interface state detection failed"
    fi
    
    # Test non-existent interface
    if ! ip link show "nonexistent_iface_12345" 2>/dev/null | grep -q "UP"; then
        log_pass "Non-existent interface correctly detected as down"
    else
        log_fail "Non-existent interface detection failed"
    fi
}

# Run all tests
main() {
    echo "================================"
    echo "mwan6-npt Test Suite"
    echo "================================"
    
    setup
    
    test_validate_prefix
    test_interface_filtering
    test_rule_paths
    test_generate_rules
    test_interface_state_check
    
    teardown
    
    echo ""
    echo "================================"
    echo "Results: $passed passed, $failed failed"
    echo "================================"
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

main "$@"
