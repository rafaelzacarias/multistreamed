# Nginx Configuration Tests

This directory contains automated tests to validate the nginx.conf configuration file.

## Test Script

### `test-nginx-config.sh`

A comprehensive test suite that validates:

1. **File Existence & Basic Structure**
   - Config file exists and is not empty
   - Required blocks (rtmp, http, events) are present

2. **RTMP Configuration**
   - Server listens on port 1935
   - Application 'live' is configured
   - Live mode is enabled
   - Push directives use environment variables correctly
   - Failover hooks (exec_publish, exec_publish_done) are configured

3. **HTTP Configuration**
   - Server listens on port 8080
   - Health check endpoint exists (`/health`)
   - Stats endpoint exists (`/stat`)

4. **Critical Validations**
   - **No resolver directive in rtmp block** (nginx-rtmp-module doesn't support it)
   - No duplicate listen directives
   - Environment variables properly formatted
   - No tabs (spaces for indentation)

5. **Syntax Validation**
   - Docker-based nginx syntax validation
   - Environment variable substitution test

## Running Tests Locally

```bash
# From project root
./tests/test-nginx-config.sh
```

Requirements:
- Bash shell
- Docker (for syntax validation test)

## CI/CD Integration

Tests run automatically on:
- Push to main branch (when nginx.conf or tests change)
- Pull requests to main branch

See `.github/workflows/test-nginx-config.yml` for the GitHub Actions configuration.

## Test Output

```
=========================================
  Nginx Configuration Validation Tests
=========================================

Testing: Nginx config file exists ... ✓ PASS
Testing: Nginx config file is not empty ... ✓ PASS
Testing: No resolver directive in rtmp block ... ✓ PASS
...

=========================================
  Test Results Summary
=========================================
Tests Passed:  20
Tests Failed:  0
=========================================

✅ All tests passed!
```

## Adding New Tests

To add a new test, use the `run_test` helper function:

```bash
run_test "Your test description" "your_test_command"
```

For complex tests, write inline test logic with proper pass/fail tracking:

```bash
echo -n "Testing: Your complex test ... "
if your_test_condition; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi
```

## Why These Tests Matter

These tests prevent common configuration errors such as:

- **Resolver in RTMP block**: The nginx-rtmp-module doesn't support the `resolver` directive. Adding it causes nginx to fail with `[emerg] "resolver" directive is not allowed here`.
- **Missing required directives**: Ensures all necessary configuration is present.
- **Syntax errors**: Catches typos and configuration mistakes before deployment.
- **Environment variable issues**: Validates that template substitution works correctly.

## Test Philosophy

- **Fast**: Tests run in seconds
- **Comprehensive**: Cover critical configuration requirements
- **Preventive**: Catch errors before they reach production
- **Clear**: Provide actionable error messages
