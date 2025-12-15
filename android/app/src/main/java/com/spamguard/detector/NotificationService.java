package com.spamguard.detector;

import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.os.Bundle;
import io.flutter.plugin.common.EventChannel;
import java.util.HashMap;
import java.util.Map;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class NotificationService extends NotificationListenerService {

    public static EventChannel.EventSink events;
    
    // Track PROCESSED MESSAGES by unique key
    // For WhatsApp: tag (chat ID) + text content = unique message
    // For others: package + tag + when timestamp
    // Value = timestamp when we processed it
    private static final java.util.concurrent.ConcurrentHashMap<String, Long> processedMessages = new java.util.concurrent.ConcurrentHashMap<>();
    
    // Expiry time: 10 minutes
    private static final long EXPIRY_MS = 10 * 60 * 1000;
    
    // Max entries to prevent memory issues
    private static final int MAX_ENTRIES = 500;
    
    // Formatter for time in HH:mm:ss format
    private static final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm:ss", Locale.US);
    private static final SimpleDateFormat timeFormatWithMs = new SimpleDateFormat("HH:mm:ss.SSS", Locale.US);

    // Generate message key based on app type
    // Uses: package + tag + text content
    // This ensures: same message in same chat = already processed
    // But: same text in different chats = new message (allowed)
    private String generateMessageKey(String packageName, String tag, String text) {
        // Normalize text content
        String normalized = text.toLowerCase().trim();
        if (normalized.length() > 200) {
            normalized = normalized.substring(0, 200);
        }
        // Key: package + tag (chat ID) + text content
        return packageName + "|" + (tag != null ? tag : "null") + "|" + normalized;
    }
    
    // Cleanup old entries
    private void cleanupOldEntries() {
        long now = System.currentTimeMillis();
        processedMessages.entrySet().removeIf(entry -> (now - entry.getValue()) > EXPIRY_MS);
        
        // If still too many, remove oldest half
        if (processedMessages.size() > MAX_ENTRIES) {
            int toRemove = processedMessages.size() / 2;
            java.util.Iterator<String> iter = processedMessages.keySet().iterator();
            while (iter.hasNext() && toRemove > 0) {
                iter.next();
                iter.remove();
                toRemove--;
            }
        }
    }

    // Check if this message was already processed
    private boolean isAlreadyProcessed(String msgKey) {
        cleanupOldEntries();
        
        Long processedTime = processedMessages.get(msgKey);
        if (processedTime != null) {
            long elapsed = System.currentTimeMillis() - processedTime;
            android.util.Log.d("NotificationService", "⏭️ ALREADY PROCESSED: " + (elapsed / 1000) + "s ago");
            return true;
        }
        return false;
    }
    
    // Mark message as processed
    private void markAsProcessed(String msgKey) {
        processedMessages.put(msgKey, System.currentTimeMillis());
        android.util.Log.d("NotificationService", "📊 Stored (total: " + processedMessages.size() + ")");
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        String packageName = sbn.getPackageName();
        int notificationId = sbn.getId();
        String tag = sbn.getTag();
        long postTimeMs = sbn.getPostTime();
        
        // Format time as HH:mm:ss (for duplicate check) and HH:mm:ss.SSS (for logging)
        String timeHHMMSS = timeFormat.format(new Date(postTimeMs));
        String timeWithMs = timeFormatWithMs.format(new Date(postTimeMs));
        
        // CRITICAL: Skip our own app's notifications to prevent infinite loop
        if (packageName.equals("com.spamguard.detector") || packageName.contains("spamguard")) {
            android.util.Log.d("NotificationService", "⏭️ Skipping our own app: " + packageName);
            return;
        }
        
        // Skip group summary notifications (they bundle multiple messages)
        // FLAG_GROUP_SUMMARY = 0x00000200
        boolean isGroupSummary = (sbn.getNotification().flags & 0x00000200) != 0;
        String groupKey = sbn.getNotification().getGroup();
        
        android.util.Log.d("NotificationService", "");
        android.util.Log.d("NotificationService", "╔═══════════════════════════════════════════════════════════╗");
        android.util.Log.d("NotificationService", "║         📨 NEW NOTIFICATION                               ║");
        android.util.Log.d("NotificationService", "╠═══════════════════════════════════════════════════════════╣");
        android.util.Log.d("NotificationService", "║ ⏰ TIME:    " + timeWithMs + " (check: " + timeHHMMSS + ")");
        android.util.Log.d("NotificationService", "║ 📦 PACKAGE: " + packageName);
        android.util.Log.d("NotificationService", "║ 🔢 ID:      " + notificationId + " | TAG: " + tag);
        android.util.Log.d("NotificationService", "║ 📋 GROUP:   " + groupKey + " | IS_SUMMARY: " + isGroupSummary);
        android.util.Log.d("NotificationService", "║ 🚩 FLAGS:   " + Integer.toHexString(sbn.getNotification().flags));
        
        if (isGroupSummary) {
            android.util.Log.d("NotificationService", "║ ⏭️ SKIPPING - This is a group summary notification");
            android.util.Log.d("NotificationService", "╚═══════════════════════════════════════════════════════════╝");
            return;
        }

        if (events == null) {
            android.util.Log.w("NotificationService", "║ ⚠️ Flutter not connected");
            android.util.Log.d("NotificationService", "╚═══════════════════════════════════════════════════════════╝");
            return;
        }

        // Get notification content
        Bundle extras = sbn.getNotification().extras;
        String title = "";
        CharSequence titleCs = extras.getCharSequence("android.title");
        if (titleCs != null) title = titleCs.toString();
        
        // Try multiple keys to get the notification text
        String text = "";
        boolean isWhatsApp = packageName.contains("whatsapp");
        
        // For WhatsApp: prefer android.text (single message) over bigText (all messages)
        // For other apps: use bigText first as it's usually more complete
        if (isWhatsApp) {
            // WhatsApp strategy: android.text has just the latest message
            CharSequence regularText = extras.getCharSequence("android.text");
            if (regularText != null && !regularText.toString().isEmpty()) {
                text = regularText.toString();
                android.util.Log.d("NotificationService", "║ 📱 WhatsApp: using android.text");
            } else {
                // Fallback: try bigText but extract last line only
                CharSequence bigText = extras.getCharSequence("android.bigText");
                if (bigText != null && !bigText.toString().isEmpty()) {
                    String fullText = bigText.toString();
                    // Extract last line (newest message) from bigText
                    String[] lines = fullText.split("\n");
                    if (lines.length > 0) {
                        text = lines[lines.length - 1].trim();
                        android.util.Log.d("NotificationService", "║ 📱 WhatsApp bigText: " + lines.length + " lines, using last");
                    }
                }
            }
            
            // Final fallback: textLines
            if (text.isEmpty()) {
                CharSequence[] textLines = extras.getCharSequenceArray("android.textLines");
                if (textLines != null && textLines.length > 0) {
                    text = textLines[textLines.length - 1].toString();
                    android.util.Log.d("NotificationService", "║ 📱 WhatsApp textLines: using last of " + textLines.length);
                }
            }
        } else {
            // Non-WhatsApp: original logic
            CharSequence bigText = extras.getCharSequence("android.bigText");
            if (bigText != null && !bigText.toString().isEmpty()) {
                text = bigText.toString();
            } else {
                CharSequence regularText = extras.getCharSequence("android.text");
                if (regularText != null && !regularText.toString().isEmpty()) {
                    text = regularText.toString();
                } else {
                    CharSequence[] textLines = extras.getCharSequenceArray("android.textLines");
                    if (textLines != null && textLines.length > 0) {
                        text = textLines[textLines.length - 1].toString();
                        android.util.Log.d("NotificationService", "║ 📋 Bundle with " + textLines.length + " lines, using last");
                    }
                }
            }
        }
        
        android.util.Log.d("NotificationService", "║ 👤 TITLE:  " + title);
        android.util.Log.d("NotificationService", "║ 📝 TEXT:   " + (text.length() > 50 ? text.substring(0, 50) + "..." : text));

        // Skip empty text
        if (text == null || text.trim().isEmpty()) {
            android.util.Log.d("NotificationService", "║ ⏭️ Empty text - skipping");
            android.util.Log.d("NotificationService", "╚═══════════════════════════════════════════════════════════╝");
            return;
        }

        // Generate MESSAGE key for deduplication
        // Key = package + tag (chat ID) + text content
        // Same app + same chat + same text = already processed
        String msgKey = generateMessageKey(packageName, tag, text);
        
        android.util.Log.d("NotificationService", "╠═══════════════════════════════════════════════════════════╣");
        android.util.Log.d("NotificationService", "║ 🔍 ALREADY PROCESSED CHECK");
        android.util.Log.d("NotificationService", "║ MsgKey: " + (msgKey.length() > 60 ? msgKey.substring(0, 60) + "..." : msgKey));
        android.util.Log.d("NotificationService", "║ Tracked: " + processedMessages.size() + " messages");
        android.util.Log.d("NotificationService", "║ Already processed? " + processedMessages.containsKey(msgKey));
        
        // Check if this message was already processed
        if (isAlreadyProcessed(msgKey)) {
            android.util.Log.d("NotificationService", "║ ❌ REJECTED - Already processed");
            android.util.Log.d("NotificationService", "╚═══════════════════════════════════════════════════════════╝");
            return;
        }
        
        // Mark as processed
        markAsProcessed(msgKey);
        
        android.util.Log.d("NotificationService", "║ ✅ ACCEPTED - Sending to Flutter");
        android.util.Log.d("NotificationService", "╚═══════════════════════════════════════════════════════════╝");

        // Send to Flutter
        Map<String, String> notificationData = new HashMap<>();
        notificationData.put("package", packageName);
        notificationData.put("title", title);
        notificationData.put("body", text);
        notificationData.put("postTime", timeHHMMSS);
        notificationData.put("tag", tag != null ? tag : "");
        
        events.success(notificationData);
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        android.util.Log.d("NotificationService", "✅ NotificationListener connected");
    }

    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        android.util.Log.w("NotificationService", "⚠️ NotificationListener disconnected");
    }
}
