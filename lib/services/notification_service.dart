import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nudge/main.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    
    // Initialize Android notification channel
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize iOS notification settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap when app is in foreground
        print('Notification tapped: ${response.payload}');
        _handleNotificationTap(response.payload);
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'nudge_channel_id',
        'Nudge Notifications',
        description: 'Channel for Nudge reminders',
        importance: Importance.high,
        playSound: true,
      );
      
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Get FCM token and save to user document
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (fcmToken != null && user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': fcmToken});
      print('FCM Token saved for user: $fcmToken');
    }
    
    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': newToken});
        print('FCM Token refreshed: $newToken');
      }
    });

    // Set up Firebase Messaging handlers
    _setupFirebaseMessaging();
  }

  void _setupFirebaseMessaging() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground FCM message: ${message.notification?.title}');
      _showLocalNotificationFromFCM(message);
    });

    // Handle when app is opened from background via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background via FCM notification');
      _handleFCMNotificationTap(message);
    });

    // Handle initial message when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from terminated state via FCM notification');
        // Delay to ensure app is fully initialized
        Future.delayed(const Duration(seconds: 1), () {
          _handleFCMNotificationTap(message);
        });
      }
    });
  }

  // Map<String, String> _parsePayload(String? payload) {
  //   if (payload == null) return {};
    
  //   final params = <String, String>{};
  //   final pairs = payload.split('&');
    
  //   for (final pair in pairs) {
  //     final split = pair.split('=');
  //     if (split.length == 2) {
  //       params[split[0]] = split[1];
  //     }
  //   }
    
  //   return params;
  // }

void _handleNotificationTap(String? payload) {
  print('Local notification tapped - forcing to notifications screen');
  
  // Always navigate to notifications screen regardless of payload
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
        arguments: {'initialTab': 3}, // 3 is notifications tab index
      );
    }
  });
}

void _handleFCMNotificationTap(RemoteMessage message) {
  print('FCM notification tapped - forcing to notifications screen');
  
  // Always navigate to notifications screen
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
        arguments: {'initialTab': 3}, // 3 is notifications tab index
      );
    }
  });
}

String _buildNotificationPayload(Map<String, dynamic> messageData) {
  // Always return the same payload for notifications tab
  final payload = {
    'screen': 'notifications',
    'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
  };
  
  return payload.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join('&');
}

  Future<void> _showLocalNotificationFromFCM(RemoteMessage message) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'nudge_channel_id',
      'Nudge Notifications',
      channelDescription: 'Channel for Nudge reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      showWhen: true,
      autoCancel: true,
    );

    const DarwinNotificationDetails iOSNotificationDetails =
        DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSNotificationDetails,
    );

    await notificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'Connection Nudge 💫',
      message.notification?.body ?? 'Time to connect!',
      notificationDetails,
      payload: _buildNotificationPayload(message.data),
    );
    
    print('Local notification shown for FCM message');
  }

  Future<void> scheduleNudgeNotification(
      int id, String title, String body, DateTime scheduledDate) async {
    try {
      // Convert DateTime to TZDateTime
      final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'nudge_channel_id',
        'Nudge Notifications',
        channelDescription: 'Channel for Nudge reminders',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        autoCancel: true,
      );

      const DarwinNotificationDetails iOSNotificationDetails =
          DarwinNotificationDetails();

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iOSNotificationDetails,
      );

      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        notificationDetails,
        uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      print('Notification scheduled: $title at $scheduledTime');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  Future<void> showInstantNotification(int id, String title, String body) async {
    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'nudge_channel_id',
        'Nudge Notifications',
        channelDescription: 'Channel for Nudge reminders',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        autoCancel: true,
      );

      const DarwinNotificationDetails iOSNotificationDetails =
          DarwinNotificationDetails();

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iOSNotificationDetails,
      );

      await notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
      );
      
      print('Instant notification shown: $title');
    } catch (e) {
      print('Error showing instant notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }
}