#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NGINX_CONF="$PROJECT_ROOT/nginx.conf"

echo "========================================="
echo "  Nginx Configuration Validation Tests  "
echo "========================================="
echo ""

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Testing: $test_name ... "
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Helper function to check if text exists in file
check_not_contains() {
    local pattern="$1"
    local context="$2"
    ! grep -q "$pattern" "$NGINX_CONF" || {
        echo -e "${RED}Error: Found '$pattern' in $context${NC}"
        return 1
    }
}

check_contains() {
    local pattern="$1"
    local context="$2"
    grep -q "$pattern" "$NGINX_CONF" || {
        echo -e "${RED}Error: Missing '$pattern' in $context${NC}"
        return 1
    }
}

# Test 1: Nginx config file exists
run_test "Nginx config file exists" "test -f '$NGINX_CONF'"

# Test 2: Nginx config file is not empty
run_test "Nginx config file is not empty" "test -s '$NGINX_CONF'"

# Test 3: No resolver directive in rtmp block
echo -n "Testing: No resolver directive in rtmp block ... "
if awk '/^rtmp {/,/^}/ {if (/resolver/) exit 1}' "$NGINX_CONF"; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo -e "${RED}Error: 'resolver' directive found in rtmp block (not supported by nginx-rtmp-module)${NC}"
    ((TESTS_FAILED++))
fi

# Test 4: Required rtmp block exists
run_test "Required rtmp block exists" "check_contains '^rtmp {' 'configuration'"

# Test 5: Required http block exists
run_test "Required http block exists" "check_contains '^http {' 'configuration'"

# Test 6: Required events block exists
run_test "Required events block exists" "check_contains '^events {' 'configuration'"

# Test 7: RTMP server listens on port 1935
run_test "RTMP server listens on port 1935" "grep -A 20 '^rtmp {' '$NGINX_CONF' | grep -q 'listen 1935'"

# Test 8: HTTP server listens on port 8080
run_test "HTTP server listens on port 8080" "grep -A 20 '^http {' '$NGINX_CONF' | grep -q 'listen 8080'"

# Test 9: Health check endpoint exists
run_test "Health check endpoint exists" "check_contains 'location /health' 'http block'"

# Test 10: Stats endpoint exists
run_test "Stats endpoint exists" "check_contains 'location /stat' 'http block'"

# Test 11: RTMP application 'live' exists
run_test "RTMP application 'live' exists" "check_contains 'application live' 'rtmp block'"

# Test 12: RTMP live mode is enabled
run_test "RTMP live mode is enabled" "grep -A 5 'application live' '$NGINX_CONF' | grep -q 'live on'"

# Test 13: Push directives use environment variables
run_test "YouTube push uses env var" "check_contains '\${YOUTUBE_STREAM_KEY}' 'push directive'"
run_test "Facebook push uses env var" "check_contains '\${FACEBOOK_STREAM_KEY}' 'push directive'"

# Test 14: exec_publish hook is configured
run_test "exec_publish hook configured" "check_contains 'exec_publish /scripts/on_publish.sh' 'application block'"

# Test 15: exec_publish_done hook is configured
run_test "exec_publish_done hook configured" "check_contains 'exec_publish_done /scripts/on_publish_done.sh' 'application block'"

# Test 16: No tabs in config (using spaces for indentation)
echo -n "Testing: No tabs in config (spaces only) ... "
if grep -q $'\t' "$NGINX_CONF"; then
    echo -e "${YELLOW}⚠ WARN${NC}"
    echo -e "${YELLOW}Warning: Found tabs in config. Consider using spaces for consistency.${NC}"
else
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
fi

# Test 17: Config uses template variables correctly
run_test "Template variables properly formatted" "grep -q '\${[A-Z_]*}' '$NGINX_CONF'"

# Test 18: No duplicate listen directives
echo -n "Testing: No duplicate listen directives ... "
LISTEN_1935=$(grep -c "listen 1935" "$NGINX_CONF" || true)
LISTEN_8080=$(grep -c "listen 8080" "$NGINX_CONF" || true)
if [ "$LISTEN_1935" -eq 1 ] && [ "$LISTEN_8080" -eq 1 ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo -e "${RED}Error: Found duplicate listen directives (1935: $LISTEN_1935, 8080: $LISTEN_8080)${NC}"
    ((TESTS_FAILED++))
fi

# Test 19: Syntax validation using Docker (if available)
if command -v docker &> /dev/null; then
    echo -n "Testing: Nginx syntax validation (Docker) ... "

    # Create a temporary directory for validation
    TMP_DIR=$(mktemp -d)
    cp "$NGINX_CONF" "$TMP_DIR/nginx.conf.template"

    # Create a test config by substituting env vars
    cat > "$TMP_DIR/test-entrypoint.sh" << 'EOF'
#!/bin/sh
export YOUTUBE_STREAM_KEY="test-key"
export FACEBOOK_STREAM_KEY="test-key"
envsubst '${YOUTUBE_STREAM_KEY} ${FACEBOOK_STREAM_KEY}' < /etc/nginx/nginx.conf.template > /tmp/nginx.conf
nginx -t -c /tmp/nginx.conf 2>&1
EOF
    chmod +x "$TMP_DIR/test-entrypoint.sh"

    # Run nginx -t in a container
    if docker run --rm \
        -v "$TMP_DIR/nginx.conf.template:/etc/nginx/nginx.conf.template:ro" \
        -v "$TMP_DIR/test-entrypoint.sh:/test-entrypoint.sh:ro" \
        --entrypoint /test-entrypoint.sh \
        tiangolo/nginx-rtmp:latest 2>&1 | grep -q "syntax is ok"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${RED}Error: Nginx syntax validation failed${NC}"
        ((TESTS_FAILED++))
    fi

    rm -rf "$TMP_DIR"
else
    echo -e "${YELLOW}⚠ SKIP${NC} - Docker not available for syntax validation"
fi

# Summary
echo ""
echo "========================================="
echo "  Test Results Summary"
echo "========================================="
echo -e "Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed:  ${RED}$TESTS_FAILED${NC}"
echo "========================================="
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}❌ Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
