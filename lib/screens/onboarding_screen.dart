import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  bool _showButton = false;
  static const platform = MethodChannel('spam_guard/permissions');
  bool _isCheckingPermission = false;
  Timer? _permissionCheckTimer;
  bool _hasVisitedSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Show button after a delay to match the scroll behavior
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showButton = true;
        });
      }
    });
    // Don't check permissions on init - always show onboarding screen first
    // Permission check will happen when user returns from settings
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('🔄 [LIFECYCLE] App state changed to: $state');
    // When app resumes, start periodic permission checking
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _hasVisitedSettings = true;
      });
      debugPrint('🔄 [LIFECYCLE] App resumed - starting permission polling');
      _startPermissionPolling();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('🔄 [LIFECYCLE] App paused - cancelling timer');
      _permissionCheckTimer?.cancel();
    }
  }

  void _startPermissionPolling() {
    debugPrint('⏰ [POLLING] Starting permission polling...');
    _permissionCheckTimer?.cancel();
    // Check immediately when resuming
    _checkPermissionAndNavigate();
    // Then check every 2 seconds for up to 30 seconds
    int attempts = 0;
    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      attempts++;
      debugPrint('⏰ [POLLING] Check #$attempts of 15');
      final isEnabled = await _isNotificationListenerEnabled();
      if (isEnabled) {
        debugPrint(
          '⏰ [POLLING] Permission granted! Cancelling timer and navigating...',
        );
        timer.cancel();
        _checkPermissionAndNavigate();
      } else if (attempts >= 15) {
        // Stop after 30 seconds
        debugPrint('⏰ [POLLING] Polling timeout - stopping after 15 checks');
        timer.cancel();
      }
    });
  }

  Future<bool> _isNotificationListenerEnabled() async {
    try {
      debugPrint(
        '🔍 [PERMISSION_CHECK] Checking notification listener status...',
      );
      final bool result = await platform.invokeMethod(
        'isNotificationListenerEnabled',
      );
      debugPrint('🔍 [PERMISSION_CHECK] Result: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('❌ [PERMISSION_CHECK] PlatformException: $e');
      return false;
    }
  }

  Future<void> _checkPermissionAndNavigate() async {
    if (_isCheckingPermission) return;

    setState(() {
      _isCheckingPermission = true;
    });

    debugPrint('🚀 [NAVIGATION] Checking permission for navigation...');
    final bool isEnabled = await _isNotificationListenerEnabled();
    debugPrint(
      '🚀 [NAVIGATION] Permission enabled: $isEnabled, mounted: $mounted',
    );

    if (isEnabled && mounted) {
      debugPrint('🚀 [NAVIGATION] Navigating to dashboard...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        debugPrint('✅ [NAVIGATION] Navigation complete!');
      }
    } else {
      debugPrint(
        '⚠️ [NAVIGATION] Cannot navigate - permission: $isEnabled, mounted: $mounted',
      );
    }

    if (mounted) {
      setState(() {
        _isCheckingPermission = false;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    // Request notification permission for Android 13+ so we can show alerts
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    // Open notification listener settings directly where user can enable the service
    try {
      await platform.invokeMethod('openNotificationListenerSettings');
    } on PlatformException {
      // Fallback to general app settings if specific intent fails
      await openAppSettings();
    }

    // Permission check will happen when app resumes via didChangeAppLifecycleState
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // App Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A8E8), Color(0xFF7B61FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A8E8).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 60,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                // App Title
                const Text(
                  'SpamGuard',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Protect yourself from spam messages',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                ),

                const SizedBox(height: 40),

                // Live Detection Preview Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: const Color(0xFF00A8E8),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Live Detection Preview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00A8E8),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Sample Messages
                      _buildSampleMessage('Bank alert: Your account...'),
                      const SizedBox(height: 12),
                      _buildSampleMessage('Meeting reminder at 3 PM'),
                      const SizedBox(height: 12),
                      _buildSampleMessage('Win \$1000 now! Click here'),

                      const SizedBox(height: 20),

                      // Tap instruction
                      const Center(
                        child: Text(
                          'Tap messages to see spam detection in action',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF00A8E8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Enable Notification Access Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enable Notification Access',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'SpamGuard needs notification access to scan incoming messages and protect you from spam in real-time.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Features List
                      _buildFeature('Automatic spam detection'),
                      const SizedBox(height: 12),
                      _buildFeature('Real-time message analysis'),
                      const SizedBox(height: 12),
                      _buildFeature('Privacy-focused, local processing'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Allow Button
                AnimatedOpacity(
                  opacity: _showButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00A8E8), Color(0xFF0077E6)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00A8E8).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _requestNotificationPermission,
                        borderRadius: BorderRadius.circular(16),
                        child: const Center(
                          child: Text(
                            'Allow Notification Access',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Continue Button (shown after returning from settings)
                if (_hasVisitedSettings)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isCheckingPermission
                                ? null
                                : () async {
                                    await _checkPermissionAndNavigate();
                                    if (mounted &&
                                        !await _isNotificationListenerEnabled()) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please enable notification access in Settings first',
                                          ),
                                          backgroundColor: Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  },
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: _isCheckingPermission
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Continue to Dashboard',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Skip button
                if (_hasVisitedSettings)
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('hasSeenOnboarding', true);
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const DashboardScreen(),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Skip for Now (Permission may not be working)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSampleMessage(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, color: Color(0xFF374151)),
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF00A8E8).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 16, color: Color(0xFF00A8E8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: Color(0xFF374151)),
          ),
        ),
      ],
    );
  }
}
