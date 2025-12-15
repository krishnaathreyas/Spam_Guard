#!/bin/bash

# SpamGuard Duplicate Detection Test Script
# Run this while monitoring: adb logcat | grep -E "DUPLICATE|ACCEPTED|ContentKey|Tracked"

echo "========================================"
echo "SpamGuard Duplicate Detection Test"
echo "========================================"
echo ""

# Test 1: Same content twice (should detect duplicate)
echo "TEST 1: Same content sent twice"
echo "  First message..."
adb shell cmd notification post -S bigtext -t "Alice" "dup_test_1" "Hello there"
sleep 3
echo "  Second message (SAME content - should be REJECTED as duplicate)..."
adb shell cmd notification post -S bigtext -t "Alice" "dup_test_2" "Hello there"
sleep 2

echo ""
echo "Check logs with: adb logcat -d | grep -E 'DUPLICATE|ACCEPTED|ContentKey' | tail -20"
echo ""

# Show results
echo "========================================"
echo "LOG RESULTS:"
echo "========================================"
adb logcat -d | grep -E "DUPLICATE|ACCEPTED|ContentKey" | tail -10

echo ""
echo "========================================"
echo "EXPECTED RESULT:"
echo "  - First 'Hello there' -> ACCEPTED"
echo "  - Second 'Hello there' -> REJECTED (DUPLICATE)"
echo "========================================"
