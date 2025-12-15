package com.spamguard.detector;

import android.content.ComponentName;
import android.content.Intent;
import android.provider.Settings;
import android.text.TextUtils;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "spam_guard/notifications";
    private static final String METHOD_CHANNEL = "spam_guard/permissions";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setStreamHandler(
                    new EventChannel.StreamHandler() {
                        @Override
                        public void onListen(Object arguments, EventChannel.EventSink events) {
                            NotificationService.events = events;
                        }

                        @Override
                        public void onCancel(Object arguments) {
                            NotificationService.events = null;
                        }
                    }
                );

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), METHOD_CHANNEL)
                .setMethodCallHandler(
                    (call, result) -> {
                        if (call.method.equals("isNotificationListenerEnabled")) {
                            boolean isEnabled = isNotificationListenerEnabled();
                            result.success(isEnabled);
                        } else if (call.method.equals("openNotificationListenerSettings")) {
                            openNotificationListenerSettings();
                            result.success(null);
                        } else {
                            result.notImplemented();
                        }
                    }
                );
    }

    private boolean isNotificationListenerEnabled() {
        String pkgName = getPackageName();
        final String flat = Settings.Secure.getString(getContentResolver(), "enabled_notification_listeners");
        android.util.Log.d("SpamGuard", "Package: " + pkgName);
        android.util.Log.d("SpamGuard", "Enabled listeners: " + flat);
        if (!TextUtils.isEmpty(flat)) {
            final String[] names = flat.split(":");
            for (int i = 0; i < names.length; i++) {
                final ComponentName cn = ComponentName.unflattenFromString(names[i]);
                android.util.Log.d("SpamGuard", "Checking component: " + cn);
                if (cn != null) {
                    if (TextUtils.equals(pkgName, cn.getPackageName())) {
                        android.util.Log.d("SpamGuard", "✅ MATCH FOUND!");
                        return true;
                    }
                }
            }
        }
        android.util.Log.d("SpamGuard", "❌ NO MATCH - Permission not granted");
        return false;
    }

    private void openNotificationListenerSettings() {
        Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
        startActivity(intent);
    }
}
