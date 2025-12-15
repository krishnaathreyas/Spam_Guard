import 'dart:async';
import 'package:flutter/services.dart';
import 'package:spam_guard/services/statistics_manager.dart';
import 'package:spam_guard/services/notification_service.dart';
import '../spam_detector.dart';

class NotificationListenerService {
  static const EventChannel _eventChannel = EventChannel(
    'spam_guard/notifications',
  );

  StreamSubscription<dynamic>? _subscription;
  bool _isListening = false;

  // Track PROCESSED MESSAGES by unique key
  // Key = package|tag|text, Value = timestamp when we processed it
  final Map<String, int> _processedMessages = {};

  // Expiry time: 10 minutes
  static const int _expiryMs = 10 * 60 * 1000;

  // Max entries
  static const int _maxEntries = 500;

  // Generate MESSAGE key: package + tag + text content
  String _generateMessageKey(String packageName, String tag, String text) {
    String normalized = text.toLowerCase().trim();
    if (normalized.length > 200) {
      normalized = normalized.substring(0, 200);
    }
    return '$packageName|$tag|$normalized';
  }

  // Cleanup old entries
  void _cleanupOldEntries() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _processedMessages.removeWhere(
      (key, timestamp) => (now - timestamp) > _expiryMs,
    );

    // If still too many, remove oldest half
    if (_processedMessages.length > _maxEntries) {
      final sortedKeys = _processedMessages.keys.toList();
      for (int i = 0; i < sortedKeys.length ~/ 2; i++) {
        _processedMessages.remove(sortedKeys[i]);
      }
    }
  }

  // Check if this message was already processed
  bool _isAlreadyProcessed(String msgKey) {
    _cleanupOldEntries();

    final processedTime = _processedMessages[msgKey];
    if (processedTime != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - processedTime;
      print('⏭️ DART: Already processed ${elapsed ~/ 1000}s ago');
      return true;
    }
    return false;
  }

  // Mark message as processed
  void _markProcessed(String msgKey) {
    _processedMessages[msgKey] = DateTime.now().millisecondsSinceEpoch;
  }

  // Start listening to notifications
  Future<void> startListening() async {
    if (_isListening) {
      print('⚠️ Already listening');
      return;
    }

    try {
      await _subscription?.cancel();

      _subscription = _eventChannel.receiveBroadcastStream().listen(
        _handleNotification,
        onError: (error) {
          print('Error listening to notifications: $error');
        },
      );
      _isListening = true;
      print('✅ Started listening to notifications');
    } catch (e) {
      print('Error starting notification listener: $e');
    }
  }

  // Stop listening to notifications
  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    print('🛑 Stopped listening to notifications');
  }

  // Handle incoming notification
  Future<void> _handleNotification(dynamic notification) async {
    if (notification == null) return;

    try {
      String message = '';
      String packageName = '';
      String body = '';
      String postTime = '';
      String tag = '';

      if (notification is Map) {
        final title = notification['title'] ?? '';
        body = notification['body'] ?? '';
        message = '$title: $body';
        packageName = notification['package'] ?? 'unknown';
        postTime = notification['postTime'] ?? '';
        tag = notification['tag'] ?? '';
      } else {
        message = notification.toString();
        body = message;
      }

      print('');
      print('╔═══════════════════════════════════════════════════════════╗');
      print('║         📨 DART: RECEIVED FROM JAVA                       ║');
      print('╠═══════════════════════════════════════════════════════════╣');
      print('║ ⏰ TIME:    $postTime');
      print('║ 📦 PACKAGE: $packageName');
      print('║ 🏷️ TAG:     $tag');
      print(
        '║ 📝 MESSAGE: ${message.length > 60 ? '${message.substring(0, 60)}...' : message}',
      );

      // Skip our own app notifications
      if (packageName == 'com.spamguard.detector' ||
          packageName.contains('spamguard') ||
          message.contains('🚨 Spam Detected') ||
          message.contains('Spam Detected from')) {
        print('║ ⏭️ Skipping our own notification');
        print('╚═══════════════════════════════════════════════════════════╝');
        return;
      }

      // Already processed check: package + tag + text content
      final msgKey = _generateMessageKey(packageName, tag, body);
      print(
        '║ 🔍 MsgKey: ${msgKey.length > 50 ? '${msgKey.substring(0, 50)}...' : msgKey}',
      );
      print('║ 🔍 Tracked: ${_processedMessages.length} messages');

      if (_isAlreadyProcessed(msgKey)) {
        print('║ ❌ Already processed - skipping');
        print('╚═══════════════════════════════════════════════════════════╝');
        return;
      }
      _markProcessed(msgKey);

      // Extract sender and text
      String notificationText = message;
      String sender = 'Unknown';

      if (message.contains(':')) {
        final colonIndex = message.indexOf(':');
        sender = message.substring(0, colonIndex).trim();
        notificationText = message.substring(colonIndex + 1).trim();
      }

      if (notificationText.isEmpty) {
        print('║ ⏭️ Empty text - skipping');
        print('╚═══════════════════════════════════════════════════════════╝');
        return;
      }

      print('╠═══════════════════════════════════════════════════════════╣');
      print('║ 🤖 CLASSIFYING...');

      // Detect spam
      final result = await SpamDetector.instance.analyzeMessage(
        notificationText,
      );
      final isSpam = result.isSpam;
      final spamProb = result.probability;

      print('║ 📊 Probability: ${(spamProb * 100).toStringAsFixed(1)}%');
      print('║ 🏷️ Result: ${isSpam ? "🚨 SPAM" : "✅ HAM"}');
      print('╚═══════════════════════════════════════════════════════════╝');

      if (isSpam) {
        await StatisticsManager.incrementSpam(
          message: notificationText,
          sender: sender,
        );

        await NotificationService.showSpamNotification(
          title: '🚨 Spam Detected from $sender',
          body: notificationText.length > 100
              ? '${notificationText.substring(0, 100)}...'
              : notificationText,
          sender: sender,
        );

        print('🚨 SPAM: $sender - $notificationText');
      } else {
        await StatisticsManager.incrementClean();
        print('✅ HAM: $sender - $notificationText');
      }
    } catch (e) {
      print('Error processing notification: $e');
    }
  }

  bool get isListening => _isListening;
}
