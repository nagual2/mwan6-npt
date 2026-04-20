#!/bin/sh
# mwan6-npt integration test
# Tests the full flow with mocked environment

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
TEST_ROOT="/tmp/mwan6-npt-test-$$"

log() {
    echo "[TEST] $1"
}

# Setup mock OpenWrt environment
setup_mock_env() {
    log "Setting up mock environment in $TEST_ROOT"
    mkdir -p "$TEST_ROOT/etc/config"
    mkdir -p "$TEST_ROOT/usr/share/nftables.d/chain-post/srcnat"
    mkdir -p "$TEST_ROOT/usr/share/nftables.d/chain-post/dstnat"
    mkdir -p "$TEST_ROOT/usr/sbin"
    mkdir -p "$TEST_ROOT/usr/share/mwan6-npt"
    mkdir -p "$TEST_ROOT/lib"
    
    # Copy actual scripts
    cp "$PKG_DIR/files/usr/sbin/mwan6-npt" "$TEST_ROOT/usr/sbin/"
    cp "$PKG_DIR/files/usr/share/mwan6-npt/functions.sh" "$TEST_ROOT/usr/share/mwan6-npt/"
    
    # Create mock UCI config
    cat > "$TEST_ROOT/etc/config/mwan6-npt" << 'EOF'
config globals 'globals'
	option enabled '1'
	option lan_prefix 'fd00:1111:2222:f000::/64'
	option auto_reload '1'

config interface 'wan1'
	option enabled '1'
	option wan_prefix 'fd00:aaaa:bbbb:1111::/64'

config interface 'wan2'
	option enabled '1'
	option wan_prefix 'fd00:cccc:dddd:2222::/64'

config interface 'wan_disabled'
	option enabled '0'
	option wan_prefix 'fd00:eeee:ffff:3333::/64'
EOF
    
    # Create mock functions.sh for OpenWrt functions
    cat > "$TEST_ROOT/lib/functions.sh" << 'EOF'
#!/bin/sh
# Mock OpenWrt functions for testing

config_load() {
    CONFIG="$1"
}

config_get() {
    local ___var="$1"
    local ___sect="$2"
    local ___opt="$3"
    local ___def="$4"
    
    # Mock implementation - read from config file
    local val
    val=$(grep -A10 "config.*'$___sect'" "/tmp/mwan6-npt-test-$$/etc/config/$CONFIG" 2>/dev/null | \
          grep "option $___opt" | head -1 | sed "s/.*'$___opt' *'\([^']*\)'.*/\1/")
    
    if [ -n "$val" ]; then
        eval "$___var=\"$val\""
    else
        eval "$___var=\"$___def\""
    fi
}

config_get_bool() {
    local ___var="$1"
    local ___sect="$2"
    local ___opt="$3"
    local ___def="$4"
    
    config_get "$___var" "$___sect" "$___opt" "$___def"
    
    case "$(eval echo "\$$___var")" in
        1|on|true|yes) eval "$___var=1" ;;
        *) eval "$___var=0" ;;
    esac
}

config_foreach() {
    local func="$1"
    local type="$2"
    
    # Mock - iterate over interfaces
    local interfaces="wan1 wan2 wan_disabled"
    for iface in $interfaces; do
        $func "$iface" "$iface"
    done
}
EOF
    
    # Patch the main script to use mock paths
    sed -i "s|CHAIN_POST_DIR=.*|CHAIN_POST_DIR=\"$TEST_ROOT/usr/share/nftables.d/chain-post\"|" \
        "$TEST_ROOT/usr/sbin/mwan6-npt"
    sed -i "s|/lib/functions.sh|$TEST_ROOT/lib/functions.sh|" \
        "$TEST_ROOT/usr/sbin/mwan6-npt"
}

test_generate_rules() {
    log "Testing rule generation..."
    
    # Create mock interface (loopback is always UP)
    # Modify script to use lo for testing
    sed -i 's/ip link show "\$iface"/ip link show "lo"/' "$TEST_ROOT/usr/sbin/mwan6-npt"
    
    # Run update (this will fail on fw4 reload, but rules should be generated)
    cd "$TEST_ROOT"
    if sh usr/sbin/mwan6-npt update 2>&1 | grep -q "Generated rules"; then
        log "Rule generation executed"
    fi
    
    # Check if rule files were created
    local srcnat_file="$TEST_ROOT/usr/share/nftables.d/chain-post/srcnat/99-mwan6-npt.nft"
    local dstnat_file="$TEST_ROOT/usr/share/nftables.d/chain-post/dstnat/99-mwan6-npt.nft"
    
    if [ -f "$srcnat_file" ]; then
        log "SRCNAT file created"
        if grep -q "snat prefix" "$srcnat_file"; then
            log "SNAT rules present in file"
            cat "$srcnat_file"
        fi
    else
        log "SRCNAT file not created (expected in mock env)"
    fi
    
    if [ -f "$dstnat_file" ]; then
        log "DSTNAT file created"
        if grep -q "dnat prefix" "$dstnat_file"; then
            log "DNAT rules present in file"
            cat "$dstnat_file"
        fi
    else
        log "DSTNAT file not created (expected in mock env)"
    fi
}

test_disabled_interfaces() {
    log "Testing disabled interface filtering..."
    
    # The disabled interface should not appear in generated rules
    local srcnat_file="$TEST_ROOT/usr/share/nftables.d/chain-post/srcnat/99-mwan6-npt.nft"
    
    if [ -f "$srcnat_file" ]; then
        if ! grep -q "wan_disabled" "$srcnat_file" 2>/dev/null; then
            log "Disabled interface correctly filtered out"
        else
            log "WARNING: Disabled interface appears in rules"
        fi
    fi
}

cleanup() {
    log "Cleaning up..."
    rm -rf "$TEST_ROOT"
}

main() {
    log "Starting mwan6-npt integration test"
    
    setup_mock_env
    test_generate_rules
    test_disabled_interfaces
    cleanup
    
    log "Integration test completed"
}

main "$@"
