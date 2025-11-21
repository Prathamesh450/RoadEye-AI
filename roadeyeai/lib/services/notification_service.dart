// lib/services/notification_service.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._(); // prevent instantiation

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _androidChannelId = 'violation_channel';
  static const String _androidChannelName = 'HMV Violations';
  static const String _androidChannelDescription =
      'Notifications for HMV vehicle violations';

  static bool _initialized = false;

  /// Initialize notification service.
  /// Call this from main() after WidgetsFlutterBinding.ensureInitialized().
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('✅ Notifications already initialized');
      return;
    }

    try {
      debugPrint('🔔 Initializing notification service...');

      // Ask permission first (especially important on iOS / Android 13+)
      await requestPermission();

      // --- Initialization settings ---
      final AndroidInitializationSettings androidInit =
          const AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification:
            (int id, String? title, String? body, String? payload) async {
          debugPrint('iOS local notification received: id=$id title=$title');
        },
      );

      final InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      // Initialize plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('📩 Notification tapped: ${response.payload}');
          // TODO: handle navigation or other logic on tap
        },
      );

      // --- Create Android notification channel (Android 8.0+) ---
      if (Platform.isAndroid) {
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: _androidChannelDescription,
          importance: Importance.high,
        );

        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      _initialized = true;
      debugPrint('✅ Notification service initialized successfully');
    } catch (e, st) {
      debugPrint('❌ Failed to initialize notifications: $e\n$st');
    }
  }

  /// Request notification permission (iOS / Android 13+).
  static Future<void> requestPermission() async {
    try {
      // permission_handler for OS-level permission requests
      final status = await Permission.notification.request();

      if (status.isGranted) {
        debugPrint('✅ Notification permission granted');
      } else if (status.isDenied) {
        debugPrint('⚠️ Notification permission denied');
      } else if (status.isPermanentlyDenied) {
        debugPrint(
            '❌ Notification permission permanently denied — opening app settings');
        await openAppSettings();
      } else {
        debugPrint('ℹ️ Notification permission status: $status');
      }
    } catch (e) {
      debugPrint('❌ Permission request error: $e');
    }
  }

  /// Request notification permissions - ADDED for compatibility
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> requestPermissions() async {
    try {
      final status = await Permission.notification.request();

      if (status.isGranted) {
        debugPrint('✅ Notification permission granted');
        return true;
      } else if (status.isDenied) {
        debugPrint('⚠️ Notification permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        debugPrint('❌ Notification permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Permission request error: $e');
      return false;
    }
  }

  /// Show a simple notification immediately.
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
    Color? color, // optional accent color for Android
  }) async {
    try {
      if (!_initialized) {
        debugPrint('⚠️ Notifications not initialized. Initializing now...');
        await initialize();
      }

      final int notificationId =
          id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

      debugPrint('📤 Sending notification: $title (id=$notificationId)');

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        // color is allowed; convert to int if provided
        color: color,
      );

      final DarwinNotificationDetails iosDetails =
          const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Notification sent successfully (id=$notificationId)');
    } catch (e, st) {
      debugPrint('❌ Failed to show notification: $e\n$st');
    }
  }

  /// Show violation notification - ADDED for compatibility
  /// Specifically for traffic violation alerts
  static Future<void> showViolationNotification({
    required String title,
    required String body,
    String? cameraId,
    int? id,
  }) async {
    try {
      if (!_initialized) {
        debugPrint('⚠️ Notifications not initialized. Initializing now...');
        await initialize();
      }

      final int notificationId =
          id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

      debugPrint(
          '🚨 Sending VIOLATION notification: $title (id=$notificationId)');

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.max, // Maximum importance for violations
        priority: Priority.max,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Colors.red, // Red color for violation alerts
        category: AndroidNotificationCategory.alarm,
      );

      final DarwinNotificationDetails iosDetails =
          const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final NotificationDetails details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: cameraId,
      );

      debugPrint(
          '✅ VIOLATION notification sent successfully (id=$notificationId)');
    } catch (e, st) {
      debugPrint('❌ Failed to show violation notification: $e\n$st');
    }
  }

  /// Show a big-text style notification (Android BigTextStyle).
  static Future<void> showBigTextNotification({
    required String title,
    required String body,
    required String bigText,
    String? payload,
    int? id,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final int notificationId =
          id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(bigText),
        playSound: true,
        enableVibration: true,
      );

      final DarwinNotificationDetails iosDetails =
          const DarwinNotificationDetails();

      final NotificationDetails details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Big text notification sent (id=$notificationId)');
    } catch (e, st) {
      debugPrint('❌ Failed to show big text notification: $e\n$st');
    }
  }

  /// Cancel all notifications.
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('🗑️ All notifications cancelled');
  }

  /// Cancel a specific notification by id.
  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
    debugPrint('🗑️ Notification $id cancelled');
  }
}
