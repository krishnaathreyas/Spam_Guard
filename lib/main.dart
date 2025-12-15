import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'spam_detector.dart';
import 'services/statistics_manager.dart';
import 'services/notification_service.dart';
import 'services/notification_listener_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load ML models and tokenizers before the UI starts.
  try {
    await SpamDetector.instance.init();
  } catch (e) {
    // If models fail to load, continue launching the app but log the error.
    // The app's screens should handle missing models gracefully.
    // ignore: avoid_print
    print('Error loading models: $e');
  }

  // DEBUG: run a quick inference at startup to capture model behavior in logs.
  // This helps surface TFLite shape/index errors immediately during boot.
  try {
    final sample = 'Test message for startup inference';
    final result = await SpamDetector.instance.isSpam(sample);
    // ignore: avoid_print
    print('Startup inference result: $result');
  } catch (e) {
    // ignore: avoid_print
    print('Startup inference error: $e');
  }

  // Initialize notification service
  await NotificationService.initialize();

  // Check and reset statistics if needed (midnight reset)
  await StatisticsManager.checkAndResetIfNeeded();

  // Set up midnight reset timer
  _setupMidnightReset();

  // Check if permission is already granted - skip onboarding if so
  String initialRoute = '/onboarding';
  try {
    const platform = MethodChannel('spam_guard/permissions');
    final bool isEnabled = await platform.invokeMethod(
      'isNotificationListenerEnabled',
    );
    if (isEnabled) {
      // Permission already granted, go directly to dashboard
      initialRoute = '/dashboard';
      print('✅ Permission already granted - skipping onboarding');
    } else {
      print('⚠️ Permission not granted - showing onboarding');
    }
  } catch (e) {
    print('Error checking permission: $e');
  }

  runApp(MyApp(initialRoute: initialRoute));
}

// Global notification listener service instance
final notificationListenerService = NotificationListenerService();

// Set up periodic check for midnight reset
Timer? _midnightResetTimer;

void _setupMidnightReset() {
  // Cancel existing timer if any
  _midnightResetTimer?.cancel();

  // Calculate time until next midnight
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
  final durationUntilMidnight = nextMidnight.difference(now);

  // Set timer for next midnight
  _midnightResetTimer = Timer(durationUntilMidnight, () {
    StatisticsManager.resetDailyStatistics();
    // Schedule next reset
    _setupMidnightReset();
  });
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpamGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: false,
      ),
      initialRoute: initialRoute,
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
    );
  }
}
