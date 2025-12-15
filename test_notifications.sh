#!/bin/bash

# Test notification script for SpamGuard

send_notification() {
    local title="$1"
    local text="$2"
    local id="${3:-1}"
    
    echo "Sending: $title - $text (ID: $id)"
    adb shell cmd notification post -S bigtext -t "$title" "tag_$id" "$text"
    sleep 1
}

case "$1" in
    1)
        echo "=== TEST 1: Single HAM message ==="
        send_notification "John" "Hey how are you doing today" 101
        ;;
    2)
        echo "=== TEST 2: Single SPAM message ==="
        send_notification "Unknown" "CONGRATULATIONS You won 1000000 dollars Click here to claim NOW" 102
        ;;
    3)
        echo "=== TEST 3: Duplicate test (same message twice) ==="
        send_notification "Alice" "Hello there friend" 103
        sleep 2
        echo "Sending SAME message again..."
        send_notification "Alice" "Hello there friend" 104
        ;;
    4)
        echo "=== TEST 4: Multiple different messages ==="
        send_notification "Bob" "Meeting at 3pm" 105
        send_notification "Carol" "Do not forget the groceries" 106
        send_notification "Dave" "FREE OFFER BUY NOW CLICK HERE" 107
        ;;
    5)
        echo "=== TEST 5: Rapid fire same content ==="
        for i in 1 2 3 4 5; do
            send_notification "Spammer" "Click this link for free money" $((200+i))
        done
        ;;
    *)
        echo "SpamGuard Notification Test Script"
        echo "==================================="
        echo "Usage: ./test_notifications.sh [test_number]"
        echo ""
        echo "Tests:"
        echo "  1 - Single HAM message"
        echo "  2 - Single SPAM message"
        echo "  3 - Duplicate test (same message twice)"
        echo "  4 - Multiple different messages"
        echo "  5 - Rapid fire same content (stress test)"
        echo ""
        echo "Make sure emulator is running and app has notification access!"
        ;;
esac
