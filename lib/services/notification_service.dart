import 'dart:io';
// import 'package:nudge/theme/app_theme.dart';
// import 'package:another_flushbar/flushbar.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nudge/main.dart';
// import 'package:nudge/services/message_service.dart';
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

  String? _pendingNudgeId;

  String? getPendingNudgeId() {
  final id = _pendingNudgeId;
  _pendingNudgeId = null; // Clear after retrieval
  return id;
}

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
        //print('Notification tapped: ${response.payload}');
        if (response.payload != null) {
          // Parse payload into a Map1
          //print('attempting to decode');

          // final String jsonString = '{"key1": 1, "key2": "hello", "key3": true}';
          final payloadMap = parsePayload(response.payload!);
          //print('finished decoding');
          //print(response.actionId); print (' is the response');
          if (payloadMap['type'] == 'event_notification') {
            //print('it is event notification');
            if (response.actionId == 'remind_me_then') {
              _handleRemindMeThenAction(payloadMap, navigatorKey.currentContext!);
              // //print('handling remind then');
            } else if (response.actionId == 'dismiss') {
              _handleDismissAction(payloadMap, navigatorKey.currentContext!);
              // //print('handling dismiss');
            } else {
              //print('forcing 1');
              _handleNotificationTap(response.payload);
            }
          } else {
            //print('forcing 2');
            print (payloadMap);
            _handleNotificationTap(response.payload);
          }
        } else {
          //print('forcing 3');
          _handleNotificationTap(null);
        }
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
      //print('FCM Token saved for user: $fcmToken');
    }
    
    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': newToken});
        //print('FCM Token refreshed: $newToken');
      }
    });

    // Set up Firebase Messaging handlers
    _setupFirebaseMessaging();
  }

  Map<String, String> parsePayload(String payload) {
    // Remove curly braces
    String trimmed = payload.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      trimmed = trimmed.substring(1, trimmed.length - 1);
    }

    final Map<String, String> result = {};
    final pairs = trimmed.split(', ');

    for (var pair in pairs) {
      final kv = pair.split(': ');
      if (kv.length == 2) {
        result[kv[0].trim()] = kv[1].trim();
      }
    }
    return result;
  }


  void _setupFirebaseMessaging() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      //print('Foreground FCM message: ${message.notification?.title}');
      _showLocalNotificationFromFCM(message);
    });

    // Handle when app is opened from background via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      //print('App opened from background via FCM notification');
      _handleFCMNotificationTap(message);
    });

    // Handle initial message when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        //print('App opened from terminated state via FCM notification');
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
    //print('Local notification tapped - forcing to notifications screen');
    
    // Always navigate to notifications screen regardless of payload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false,
          arguments: {'initialTab': 2}, // 2 is notifications tab index
        );
      }
    });
  }

  Future<void> _handleRemindMeThenAction(Map<String, dynamic> data, BuildContext context) async {
    final notificationId = data['notificationId'];
    
    if (notificationId == null) {
      //print('No notificationId found in data');
      return;
    }
    _showSnackBar('Reminder rescheduled!', Color.fromARGB(255, 18, 132, 27), context);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('scheduleEventReminderForActualDate')
          .call({'notificationId': notificationId});
      
      // if (result.data['success'] == true) {
      //   _showSnackBar('Reminder scheduled!', Color.fromARGB(255, 18, 132, 27));
      // } else {
      //   _showSnackBar('Could not schedule reminder', Color.fromARGB(255, 149, 19, 30));
      // }
    } catch (e) {
      //print('Error scheduling reminder: $e');
      // _showSnackBar('Error scheduling reminder', Color.fromARGB(255, 136, 17, 27));
    }
  }

  Future<void> _handleDismissAction(Map<String, dynamic> data, BuildContext context) async {
    final notificationId = data['notificationId'];
    
    if (notificationId == null) {
      //print('No notificationId found in data');
      return;
    }
    _showSnackBar('Dismissed Reminder', Color(0xff999999), context);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('dismissEventNotification')
          .call({'notificationId': notificationId});
      
      // if (result.data['success'] == true) {
      //   _showSnackBar('Notification dismissed', Color.fromARGB(255, 19, 144, 29));
      // } else {
      //   _showSnackBar('Could not dismiss notification', Color.fromARGB(255, 152, 21, 32));
      // }
    } catch (e) {
      //print('Error dismissing notification: $e');
      _showSnackBar('Error dismissing notification',  Color.fromARGB(255, 134, 17, 27), context);
    }
  }

  void _showSnackBar(String message, Color messageColor, BuildContext context) {
     Flushbar(
        padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
        flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
        forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
        backgroundColor: messageColor,
        messageText: Center(
            child: Text(message, style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
      ).show(navigatorKey.currentContext!);
    //  TopMessageService().showMessage(
    //       context: navigatorKey.currentContext!,
    //       message: message,
    //       backgroundColor: AppColors.success,
    //       icon: Icons.check,
    //     );
  }


  void _handleFCMNotificationTap(RemoteMessage message) {
    //print('FCM notification tapped - forcing to notifications screen');
    
    // Extract nudgeId from message data
    final nudgeId = message.data['nudgeId'];
    //print('NudgeId from notification: $nudgeId');
    
    // Store nudgeId in a global variable or pass through navigation
    if (nudgeId != null) {
      // Use a global variable to track pending nudge action
      _pendingNudgeId = nudgeId;
    }
    
    // Always navigate to notifications screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false,
          arguments: {
            'initialTab': 2, // 2 is notifications tab index
            'pendingNudgeId': nudgeId, // Pass nudgeId through arguments
          },
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
    final data = message.data;

    if (data['type'] == 'event_notification') {
      // Event notification with action buttons
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'event_notifications',
        'Event Notifications',
        channelDescription: 'Birthday and anniversary notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        showWhen: true,
        autoCancel: true,
        actions: [
          AndroidNotificationAction(
            'remind_me_then',
            'Remind Me Then',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            'Dismiss',
            showsUserInterface: true,
            // cancelNotification: true,
          ),
        ],
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        categoryIdentifier: 'EVENT_NOTIFICATION_ACTIONS',
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await notificationsPlugin.show(
        message.hashCode,
        message.notification?.title ?? '🎉 Upcoming Event!',
        message.notification?.body ?? 'This is a reminder for the event!',
        platformChannelSpecifics,
        payload: message.data.isNotEmpty ? message.data.toString() : null,
      );

      //print('Event notification with actions shown');
    } else {
      // Regular notification without action buttons
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
        message.notification?.title ?? 'Nudge 💫',
        message.notification?.body ?? 'Time to connect!',
        notificationDetails,
        payload: _buildNotificationPayload(message.data),
      );

      //print('Regular notification shown');
    }
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
      
      //print('Notification scheduled: $title at $scheduledTime');
    } catch (e) {
      //print('Error scheduling notification: $e');
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
      
      //print('Instant notification shown: $title');
    } catch (e) {
      //print('Error showing instant notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }
}