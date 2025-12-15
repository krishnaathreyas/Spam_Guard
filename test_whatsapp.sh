#!/bin/bash

echo "========================================"
echo "WhatsApp Deduplication Test"
echo "========================================"
echo ""
echo "Logic for WhatsApp:"
echo "  Key = tag (chat ID) + text content"
echo "  Same tag + same text = DUPLICATE"
echo "  Same tag + different text = NEW MESSAGE"
echo "  Different tag + same text = NEW MESSAGE (different chat)"
echo ""

# Clear logcat
adb logcat -c

echo "=== TEST 1: First message from Alice chat ==="
adb shell cmd notification post -S bigtext -t "Alice" "chat_alice_123" "Hello there"
sleep 2

echo ""
echo "=== TEST 2: Same message from Alice chat (should be REJECTED) ==="
adb shell cmd notification post -S bigtext -t "Alice" "chat_alice_123" "Hello there"
sleep 2

echo ""
echo "=== TEST 3: Different message from Alice chat (should be ACCEPTED) ==="
adb shell cmd notification post -S bigtext -t "Alice" "chat_alice_123" "How are you"
sleep 2

echo ""
echo "=== TEST 4: Same text but from Bob chat (should be ACCEPTED - different chat) ==="
adb shell cmd notification post -S bigtext -t "Bob" "chat_bob_456" "Hello there"
sleep 2

echo ""
echo "=== TEST 5: Re-fire Alice's first message again (should be REJECTED) ==="
adb shell cmd notification post -S bigtext -t "Alice" "chat_alice_123" "Hello there"
sleep 2

echo ""
echo "========================================"
echo "Checking results..."
echo "========================================"
echo ""
adb logcat -d | grep -E "MsgKey:|ACCEPTED|REJECTED" | tail -20

echo ""
echo "Expected:"
echo "  Test 1: ACCEPTED (new message)"
echo "  Test 2: REJECTED (same chat + same text)"
echo "  Test 3: ACCEPTED (same chat + different text)"
echo "  Test 4: ACCEPTED (different chat + same text)"
echo "  Test 5: REJECTED (same chat + same text)"
