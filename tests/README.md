# mwan6-npt Tests

This directory contains test scripts for the mwan6-npt package.

## Test Files

| File | Description |
|------|-------------|
| `run_tests.sh` | Main test suite runner |
| `test_integration.sh` | End-to-end integration tests |
| `test_prefix_validation.sh` | IPv6 prefix format validation tests |

## Running Tests

### Basic Tests

```bash
cd tests/
./run_tests.sh
```

### Integration Tests

```bash
./test_integration.sh
```

### Prefix Validation Only

```bash
./test_prefix_validation.sh
```

## Test Coverage

### Unit Tests (`run_tests.sh`)

- **UCI Configuration Loading**: Tests loading of globals and interface sections
- **IPv6 Prefix Validation**: Validates format of ULA and global prefixes
- **Rule Generation**: Tests SNAT/DNAT rule generation
- **Interface Filtering**: Tests enabled/disabled interface handling
- **File Path Validation**: Ensures correct fw4 chain-post paths
- **Interface State Detection**: Tests UP/DOWN detection logic

### Integration Tests (`test_integration.sh`)

- **Full Flow**: Tests complete flow from config to rule generation
- **Mock Environment**: Simulates OpenWrt UCI environment
- **Rule File Creation**: Verifies rule files are created correctly
- **Disabled Interface Handling**: Ensures disabled interfaces are excluded

### Validation Tests (`test_prefix_validation.sh`)

- **Valid Prefixes**: fd00::/8 ULA, 2001:db8::/32 documentation, 2a00::/12 global
- **Invalid Prefixes**: IPv4 addresses, malformed strings, incomplete formats

## Adding New Tests

1. Create test function in `run_tests.sh`
2. Call it from `main()`
3. Use `log_pass` and `log_fail` for results

Example:

```bash
test_my_feature() {
    log_info "Test: My feature"
    
    if [ some_condition ]; then
        log_pass "Feature works"
    else
        log_fail "Feature broken"
    fi
}
```

## CI/CD Integration

Tests return exit code 0 on success, non-zero on failure:

```bash
./run_tests.sh || exit 1
```

## Requirements

- sh/bash shell
- grep, sed, awk (standard Unix tools)
- Optional: OpenWrt `functions.sh` for full UCI tests
