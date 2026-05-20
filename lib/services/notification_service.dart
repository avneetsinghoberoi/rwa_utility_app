import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Background handler — must be a top-level function ───────────────────────
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized at this point.
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

// ─── Notification channel definition ─────────────────────────────────────────
const AndroidNotificationChannel _kChannel = AndroidNotificationChannel(
  'rwa_channel',           // must match what Cloud Functions send
  'RWA Notifications',
  description: 'Society dues, notices, complaints and payment updates',
  importance: Importance.high,
);

// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Call once after Firebase.initializeApp() in main().
  static Future<void> initialize() async {
    try {
      // 1️⃣  Register background message handler (must be set before the app
      //     is fully running so the isolate can pick it up).
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

      // 2️⃣  Create the Android notification channel (no-op on iOS).
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_kChannel);
      } catch (e) {
        debugPrint('[Notification] Channel creation error (non-critical): $e');
      }

      // 3️⃣  Initialise the local notifications plugin.
      try {
        await _plugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
      } catch (e) {
        debugPrint('[Notification] Plugin initialization error (non-critical): $e');
      }

      // 4️⃣  Request permission (critical on iOS; Android 13+ uses the manifest
      //     POST_NOTIFICATIONS permission but the runtime request is still needed).
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        debugPrint('[Notification] Permission request error (non-critical): $e');
      }

      // 5️⃣  iOS: show notifications while the app is in the foreground.
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        debugPrint('[Notification] Foreground options error (non-critical): $e');
      }

      // 6️⃣  Listen for foreground messages and show a local notification.
      FirebaseMessaging.onMessage.listen(_showLocalNotification);

      // 7️⃣  Save FCM token whenever the user is (or becomes) signed in.
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) saveToken();
      });

      // Refresh token automatically when FCM rotates it.
      FirebaseMessaging.instance.onTokenRefresh.listen((_) => saveToken());

      debugPrint('✅ NotificationService initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ NotificationService initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - allow app to continue without notifications
    }
  }

  // ── Show a heads-up notification while the app is in the foreground ──────
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    await _plugin.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannel.id,
          _kChannel.name,
          channelDescription: _kChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Save (or refresh) the FCM token for the currently signed-in user ─────
  static Future<void> saveToken([String? token]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      token ??= await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcm_token': token});

      debugPrint('[FCM] Token saved for uid=${user.uid}');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  // ── Call on logout to remove the stale token from Firestore ──────────────
  static Future<void> clearToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcm_token': FieldValue.delete()});

      debugPrint('[FCM] Token cleared');
    } catch (e) {
      debugPrint('[FCM] Failed to clear token: $e');
    }
  }
}
