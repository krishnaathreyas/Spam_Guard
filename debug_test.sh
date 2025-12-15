#!/bin/bash

# Debug test script for SpamGuard
# This clears logs and monitors for duplicate detection

echo "========================================"
echo "SpamGuard Debug Test"
echo "========================================"
echo ""
echo "Step 1: Clearing old logs..."
adb logcat -c
echo "✅ Logs cleared"
echo ""
echo "Step 2: Starting log monitor in background..."
echo "Watch for:"
echo "  - ⏭️ DUPLICATE: Content already processed"
echo "  - ❌ REJECTED - Content already processed"
echo "  - 🚨 SPAM or ✅ HAM classification"
echo ""
echo "========================================"
echo "LOGS (Ctrl+C to stop):"
echo "========================================"

# Monitor only relevant logs
adb logcat | grep -E "(NotificationService|flutter|DUPLICATE|SPAM|HAM|REJECTED|ACCEPTED|WhatsApp)" --line-buffered
