import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StatisticsManager {
  static const String _keySpamDetected = 'spam_detected';
  static const String _keyCleanMessages = 'clean_messages';
  static const String _keyBlockedToday = 'blocked_today';
  static const String _keyLastResetDate = 'last_reset_date';
  static const String _keyYesterdaySpam = 'yesterday_spam';
  static const String _keySpamSources = 'spam_sources';
  static const String _keyRecentlyBlocked = 'recently_blocked';

  // Get statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final prefs = await SharedPreferences.getInstance();

    final spamDetected = prefs.getInt(_keySpamDetected) ?? 0;
    final cleanMessages = prefs.getInt(_keyCleanMessages) ?? 0;
    final blockedToday = prefs.getInt(_keyBlockedToday) ?? 0;
    final yesterdaySpam = prefs.getInt(_keyYesterdaySpam) ?? 0;

    // Calculate yesterday change percentage
    double yesterdayChange = 0.0;
    if (yesterdaySpam > 0 && blockedToday > 0) {
      yesterdayChange = ((yesterdaySpam - blockedToday) / yesterdaySpam * 100)
          .abs();
    } else if (blockedToday > 0 && yesterdaySpam == 0) {
      yesterdayChange = 100.0;
    }

    // Get spam sources (stored as JSON string)
    final spamSourcesJson = prefs.getString(_keySpamSources) ?? '[]';
    List<Map<String, dynamic>> spamSources = [];
    try {
      if (spamSourcesJson.isNotEmpty && spamSourcesJson != '[]') {
        final decoded = json.decode(spamSourcesJson) as List;
        spamSources = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      spamSources = [];
    }

    // Get recently blocked messages
    final recentlyBlockedJson = prefs.getString(_keyRecentlyBlocked) ?? '[]';
    List<Map<String, dynamic>> recentlyBlocked = [];
    try {
      if (recentlyBlockedJson.isNotEmpty && recentlyBlockedJson != '[]') {
        final decoded = json.decode(recentlyBlockedJson) as List;
        recentlyBlocked = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      recentlyBlocked = [];
    }

    return {
      'spamDetected': spamDetected,
      'cleanMessages': cleanMessages,
      'blockedToday': blockedToday,
      'yesterdayChange': yesterdayChange,
      'totalMessages': spamDetected + cleanMessages,
      'spamSources': spamSources,
      'recentlyBlocked': recentlyBlocked,
    };
  }

  // Increment spam count
  static Future<void> incrementSpam({
    required String message,
    required String sender,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Increment spam detected
    final currentSpam = prefs.getInt(_keySpamDetected) ?? 0;
    await prefs.setInt(_keySpamDetected, currentSpam + 1);

    // Increment blocked today
    final currentBlocked = prefs.getInt(_keyBlockedToday) ?? 0;
    await prefs.setInt(_keyBlockedToday, currentBlocked + 1);

    // Add to recently blocked (keep last 10)
    final recentlyBlockedJson = prefs.getString(_keyRecentlyBlocked) ?? '[]';
    List<Map<String, dynamic>> recentlyBlocked = [];
    try {
      if (recentlyBlockedJson.isNotEmpty && recentlyBlockedJson != '[]') {
        recentlyBlocked = List<Map<String, dynamic>>.from(
          json.decode(recentlyBlockedJson) as List,
        );
      }
    } catch (e) {
      recentlyBlocked = [];
    }

    // Add new blocked message at the beginning
    recentlyBlocked.insert(0, {
      'content': message.length > 50
          ? '${message.substring(0, 50)}...'
          : message,
      'sender': sender,
      'time': _getTimeAgo(DateTime.now()),
    });

    // Keep only last 10
    if (recentlyBlocked.length > 10) {
      recentlyBlocked = recentlyBlocked.sublist(0, 10);
    }

    await prefs.setString(_keyRecentlyBlocked, json.encode(recentlyBlocked));

    // Update spam sources
    await _updateSpamSource(sender);
  }

  // Increment clean messages count
  static Future<void> incrementClean() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyCleanMessages) ?? 0;
    await prefs.setInt(_keyCleanMessages, current + 1);
  }

  // Reset statistics at midnight
  static Future<void> resetDailyStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Save yesterday's spam count before resetting
    final currentBlocked = prefs.getInt(_keyBlockedToday) ?? 0;
    await prefs.setInt(_keyYesterdaySpam, currentBlocked);

    // Reset daily counters
    await prefs.setInt(_keyBlockedToday, 0);
    await prefs.setString(_keyLastResetDate, now.toIso8601String());

    // Clear recently blocked (optional - you might want to keep them)
    // await prefs.setString(_keyRecentlyBlocked, '[]');
  }

  // Check if reset is needed (called on app start)
  static Future<void> checkAndResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDateStr = prefs.getString(_keyLastResetDate);

    if (lastResetDateStr == null) {
      // First time, set today as last reset
      await prefs.setString(
        _keyLastResetDate,
        DateTime.now().toIso8601String(),
      );
      return;
    }

    final lastResetDate = DateTime.parse(lastResetDateStr);
    final now = DateTime.now();

    // Check if we've crossed midnight
    if (now.year > lastResetDate.year ||
        now.month > lastResetDate.month ||
        now.day > lastResetDate.day) {
      await resetDailyStatistics();
    }
  }

  // Update spam sources
  static Future<void> _updateSpamSource(String sender) async {
    final prefs = await SharedPreferences.getInstance();
    final spamSourcesJson = prefs.getString(_keySpamSources) ?? '[]';

    List<Map<String, dynamic>> spamSources = [];
    try {
      if (spamSourcesJson.isNotEmpty && spamSourcesJson != '[]') {
        spamSources = List<Map<String, dynamic>>.from(
          json.decode(spamSourcesJson) as List,
        );
      }
    } catch (e) {
      spamSources = [];
    }

    // Find existing source or create new
    final sourceIndex = spamSources.indexWhere((s) => s['name'] == sender);
    if (sourceIndex >= 0) {
      spamSources[sourceIndex]['count'] =
          (spamSources[sourceIndex]['count'] as int) + 1;
    } else {
      // Categorize sender
      String category = _categorizeSender(sender);
      final categoryIndex = spamSources.indexWhere(
        (s) => s['name'] == category,
      );
      if (categoryIndex >= 0) {
        spamSources[categoryIndex]['count'] =
            (spamSources[categoryIndex]['count'] as int) + 1;
      } else {
        spamSources.add({'name': category, 'count': 1});
      }
    }

    await prefs.setString(_keySpamSources, json.encode(spamSources));
  }

  static String _categorizeSender(String sender) {
    final lower = sender.toLowerCase();
    if (lower.contains('marketing') || lower.contains('promo')) {
      return 'Marketing Alerts';
    } else if (lower.contains('unknown') ||
        lower.contains('+') ||
        RegExp(r'^\d+$').hasMatch(sender.replaceAll(RegExp(r'[^\d]'), ''))) {
      return 'Unknown Senders';
    } else if (lower.contains('sms') || lower.contains('text')) {
      return 'Promotional SMS';
    } else {
      return 'Other';
    }
  }

  static String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }
  }

  // Reset all statistics (for testing/fresh install simulation)
  static Future<void> resetAllStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySpamDetected);
    await prefs.remove(_keyCleanMessages);
    await prefs.remove(_keyBlockedToday);
    await prefs.remove(_keyYesterdaySpam);
    await prefs.remove(_keyLastResetDate);
    await prefs.remove(_keySpamSources);
    await prefs.remove(_keyRecentlyBlocked);
    print('✅ All statistics have been reset to 0');
  }
}
