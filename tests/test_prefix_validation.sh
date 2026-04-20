#!/bin/sh
# Test IPv6 prefix validation

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source functions if available
if [ -f "$SCRIPT_DIR/../files/usr/share/mwan6-npt/functions.sh" ]; then
    . "$SCRIPT_DIR/../files/usr/share/mwan6-npt/functions.sh"
fi

test_validate_ipv6_prefix() {
    local test_cases=(
        # Valid prefixes
        "fd00:1111:2222:f000::/64:valid"
        "fd00::/64:valid"
        "fd00:aaaa:bbbb:cccc::/64:valid"
        "2001:db8::/64:valid"
        "2a11:6c7:f05:14f::/64:valid"
        "2a0f:cdc6:2024:1f4::/64:valid"
        
        # Invalid prefixes
        "192.168.1.0/24:invalid"
        "10.0.0.0/8:invalid"
        "not-a-prefix:invalid"
        "fd00:1111:invalid"
        "::1/128:invalid"
        ":invalid"
        "/64:invalid"
    )
    
    local passed=0
    local failed=0
    
    echo "Testing IPv6 prefix validation..."
    
    for case in "${test_cases[@]}"; do
        local prefix="${case%%:*}"
        local expected="${case##*:}"
        local result
        
        # Test validation regex
        if echo "$prefix" | grep -qE '^[0-9a-fA-F:]+::/[0-9]+$'; then
            result="valid"
        else
            result="invalid"
        fi
        
        if [ "$result" = "$expected" ]; then
            echo "  [PASS] '$prefix' -> $result"
            passed=$((passed + 1))
        else
            echo "  [FAIL] '$prefix' -> expected $expected, got $result"
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo "Results: $passed passed, $failed failed"
    
    return $failed
}

test_prefix_formats() {
    echo ""
    echo "Testing prefix format variations..."
    
    local formats=(
        "fd00:1111:2222:f000::/64:correct"
        "FD00:1111:2222:F000::/64:correct"
        "fd00:1111:2222:f000:0000:0000:0000:0000/64:incorrect"
        "fd00:1111:2222:f000/64:incorrect"
    )
    
    for fmt in "${formats[@]}"; do
        local prefix="${fmt%%:*}"
        local expected="${fmt##*:}"
        
        # Check if it matches our expected format
        if echo "$prefix" | grep -qE '^[0-9a-fA-F:]+::/[0-9]+$'; then
            echo "  '$prefix' matches regex"
        else
            echo "  '$prefix' does not match regex"
        fi
    done
}

main() {
    echo "================================"
    echo "IPv6 Prefix Validation Tests"
    echo "================================"
    
    test_validate_ipv6_prefix
    test_prefix_formats
}

main "$@"
