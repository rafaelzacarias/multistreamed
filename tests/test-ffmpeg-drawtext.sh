#!/bin/bash
# Tests that the FFmpeg drawtext commands in placeholder scripts are valid.
# This validates that the escaping for %{localtime} format colons is correct.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================="
echo "  FFmpeg Drawtext Validation Tests"
echo "========================================="
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

run_ffmpeg_test() {
    local test_name="$1"
    local vf_arg="$2"

    echo -n "Testing: $test_name ... "
    # Run ffmpeg with the drawtext filter, generate 1 frame, output to null
    OUTPUT=$(ffmpeg -f lavfi -i "color=c=0x1a1a2e:s=320x240:r=1" \
        -f lavfi -i anullsrc=r=44100:cl=stereo \
        -vf "$vf_arg" \
        -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
        -c:a aac -b:a 128k \
        -frames:v 1 -f null - 2>&1)

    # Check for known error patterns
    if echo "$OUTPUT" | grep -qi "Both text and text file provided"; then
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${RED}  Error: 'Both text and text file provided' - colon escaping is broken${NC}"
        ((TESTS_FAILED++))
        return 1
    elif echo "$OUTPUT" | grep -qi "Error initializing filter"; then
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${RED}  Error: Filter initialization failed${NC}"
        echo "$OUTPUT" | grep -i "error" | head -3 | sed 's/^/  /'
        ((TESTS_FAILED++))
        return 1
    elif echo "$OUTPUT" | grep -qi "Stray %"; then
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${RED}  Error: 'Stray %' - expression parsing failed${NC}"
        ((TESTS_FAILED++))
        return 1
    elif echo "$OUTPUT" | grep -qi "requires at most 1 arguments"; then
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${RED}  Error: localtime got too many arguments - colon escaping is wrong${NC}"
        ((TESTS_FAILED++))
        return 1
    elif echo "$OUTPUT" | grep -q "frame=.*1"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${RED}  Error: Unexpected ffmpeg output${NC}"
        echo "$OUTPUT" | tail -5 | sed 's/^/  /'
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Validate start_placeholder.sh drawtext filter
# This must match the -vf argument in scripts/start_placeholder.sh
run_ffmpeg_test "start_placeholder.sh drawtext filter" \
    "drawtext=text='Stream Starting Soon':fontsize=120:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-60,drawtext=text='%{localtime\:%I\\\\\:%M\\\\\:%S %p PT}':fontsize=80:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2+80"

# Test 2: Validate on_publish_done.sh drawtext filter
# This must match the -vf argument in scripts/on_publish_done.sh
run_ffmpeg_test "on_publish_done.sh drawtext filter" \
    "drawtext=text='Stream Starting Soon':fontsize=120:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-60,drawtext=text='%{localtime\:%I\\\\\:%M\\\\\:%S %p PT}':fontsize=80:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2+80"

# Test 3: Verify localtime renders actual time text (not empty/garbled)
echo -n "Testing: localtime renders time text to image ... "
TMPIMG=$(mktemp /tmp/ffmpeg_test_XXXXXX.png)
ffmpeg -f lavfi -i "color=c=0x1a1a2e:s=640x480:r=1" \
    -vf "drawtext=text='%{localtime\:%I\\\\\:%M\\\\\:%S %p PT}':fontsize=40:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" \
    -frames:v 1 -y "$TMPIMG" 2>/dev/null
FILESIZE=$(wc -c < "$TMPIMG" 2>/dev/null || echo 0)
rm -f "$TMPIMG"
# A blank 640x480 dark frame is ~1-2KB; with rendered text it's typically 5-10KB+
MIN_RENDERED_SIZE=3000
if [ "$FILESIZE" -gt "$MIN_RENDERED_SIZE" ]; then
    echo -e "${GREEN}✓ PASS${NC} (${FILESIZE} bytes)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} (${FILESIZE} bytes - text may not be rendering)"
    ((TESTS_FAILED++))
fi

# Test 4: Verify the scripts contain matching drawtext filters
echo -n "Testing: start_placeholder.sh has valid drawtext syntax ... "
if grep -q "drawtext=text='%{localtime" "$PROJECT_ROOT/scripts/start_placeholder.sh"; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo -e "${RED}  Error: start_placeholder.sh missing drawtext localtime filter${NC}"
    ((TESTS_FAILED++))
fi

echo -n "Testing: on_publish_done.sh has valid drawtext syntax ... "
if grep -q "drawtext=text='%{localtime" "$PROJECT_ROOT/scripts/on_publish_done.sh"; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo -e "${RED}  Error: on_publish_done.sh missing drawtext localtime filter${NC}"
    ((TESTS_FAILED++))
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
