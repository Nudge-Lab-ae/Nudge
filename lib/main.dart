// lib/main.dart
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nudge/firebase_options.dart';
import 'package:nudge/screens/analytics/analytics_screen.dart';
import 'package:nudge/screens/auth/complete_profile_screen.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
import 'package:nudge/screens/splash_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/contacts/contacts_list_screen.dart';
import 'screens/contacts/add_contact_screen.dart';
import 'screens/contacts/import_contacts_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/groups/groups_list_screen.dart';
import 'services/auth_service.dart';
import 'models/user.dart' as user;
// import 'package:firebase_app_check/firebase_app_check.dart';

// Create a GlobalKey for navigator to handle notifications when app is in background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Initialize flutter_local_notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('stage 1 - Widgets binding initialized');
  
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    print('stage 2 - Orientation set');

    // Debug platform detection
    if (kIsWeb) {
      print('Running on Web');
    } else if (Platform.isAndroid) {
      print('Running on Android');
    } else if (Platform.isIOS) {
      print('Running on iOS');
    }

    print('Attempting Firebase initialization...');
    
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    //   name: Platform.isAndroid?"Nudge":"Nudge-iOS"
    // );
    if (Platform.isIOS) {
       await Firebase.initializeApp();
    } else {
       await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
       name: "Nudge"
  );
    }
   
    print('stage 3 - Firebase initialized successfully');
    
  } catch (e, stack) {
    print('Error during initialization: $e');
    print('Stack trace: $stack');
    
    // Try fallback initialization without options
    try {
      print('Attempting fallback Firebase initialization...');
      await Firebase.initializeApp();
      print('Fallback Firebase initialization successful');
    } catch (e2) {
      print('Fallback also failed: $e2');
    }
  }
  
  runApp(const NudgeApp());
  _initializeInBackground();
}

Future<void> _initializeInBackground() async {
  try {
   
    
    // Initialize other services in background
    await initializeLocalNotifications();
    await Future.delayed(Duration(seconds: 2));
    await initializeFCM();
    
    final nudgeService = NudgeService();
    await nudgeService.initialize();
    
    print('Background initialization completed');
  } catch (e) {
    print('Background initialization error: $e');
  }
}

// void printDebugToken() async {
//   final token = await FirebaseAppCheck.instance.getToken(true);
//   print('Debug App Check token: $token');
  
//   // You'll need to register this token in Firebase Console
//   // under App Check → Manage debug tokens
// }

Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap
      _handleNotificationTap(response.payload);
    },
  );

  // Create notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications',
    importance: Importance.high,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> initializeFCM() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  print('Notification permission: ${settings.authorizationStatus}');

  if (Platform.isIOS) {
    _setupIOSFCM();
  }

  // Get FCM token - we'll store it when we have a user logged in
  String? token = await messaging.getToken();
  if (token != null) {
    print('FCM Token: $token');
    // Token will be stored in user document when user is logged in
  }

  // Handle token refresh
  messaging.onTokenRefresh.listen((newToken) async {
    print('FCM token refreshed: $newToken');
    // Update token in user document when user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final apiService = ApiService();
      await apiService.updateUser({'fcmToken': newToken});
    }
  });

  // Set up foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message received: ${message.notification?.title}');
    _showLocalNotification(message);
  });

  // Set up background message handler
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('App opened from background via notification');
    _handleBackgroundMessage(message);
  });

  // Handle notification when app is terminated
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    print('App opened from terminated state via notification');
    _handleTerminatedMessage(initialMessage);
  }
}

void _setupIOSFCM() {
  // Request APNS token for iOS
  FirebaseMessaging.instance.getAPNSToken().then((token) {
    print('APNS Token: $token');
  });
  
  // Handle token refresh for iOS
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async{
    print('FCM Token refreshed: $token');
    final apiService = ApiService();
    await apiService.updateUser({'fcmToken': token});
  });
  
  // Handle initial message when app is opened from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      print('App opened from terminated state with message: ${message.data}');
      _handleMessage(message);
    }
  });
  
  // Handle messages when app is in foreground
  FirebaseMessaging.onMessage.listen((message) {
    print('Foreground message: ${message.data}');
    _handleMessage(message);
  });
  
  // Handle when app is in background but not terminated
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print('App opened from background with message: ${message.data}');
    _handleMessage(message);
  });
}

// void _setupTokenRefreshListener() {
//   // Set up token refresh listener
//   FirebaseMessaging.instance.onTokenRefresh.listen((token) async{
//     print('FCM Token refreshed: $token');
//     final apiService = ApiService();
//     await apiService.updateUser({'fcmToken': token});
//   });
// }

void _handleMessage(RemoteMessage message) {
  // Handle your notification message here
  print('Handling message: ${message.data}');
  
  // You can navigate to specific screens based on message data
  // or show local notifications, etc.
}

void _showLocalNotification(RemoteMessage message) {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'This channel is used for important notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    showWhen: true,
    autoCancel: true,
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails();

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'New Nudge',
    message.notification?.body ?? 'Time to connect with your contact!',
    platformChannelSpecifics,
    payload: _buildNotificationPayload(message),
  );
}

String _buildNotificationPayload(RemoteMessage message) {
  // Create a payload string with relevant data
  final payload = {
    'type': message.data['type'] ?? 'nudge',
    'nudgeId': message.data['nudgeId'] ?? '',
    'contactId': message.data['contactId'] ?? '',
    'contactName': message.data['contactName'] ?? '',
    'screen': message.data['screen'] ?? 'notifications',
  };
  
  return payload.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join('&');
}

void _handleNotificationTap(String? payload) {
  print('Notification tapped with payload: $payload');
  
  if (payload != null) {
    final params = Uri.splitQueryString(payload);
    final screen = params['screen'] ?? 'notifications';
    
    // Navigate to appropriate screen based on notification data
    if (navigatorKey.currentState != null) {
      switch (screen) {
        case 'notifications':
          navigatorKey.currentState!.pushNamed('/notifications');
          break;
        // Add more cases for other screens as needed
        default:
          navigatorKey.currentState!.pushNamed('/notifications');
      }
    }
  }
}

void _handleBackgroundMessage(RemoteMessage message) {
  print('Handling background message: ${message.data}');
  _handleNotificationTap(_buildNotificationPayload(message));
}

void _handleTerminatedMessage(RemoteMessage message) {
  print('Handling terminated message: ${message.data}');
  // Store this and handle it when the app fully initializes
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _handleNotificationTap(_buildNotificationPayload(message));
  });
}

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'NUDGE',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primaryColor: const Color.fromRGBO(45, 161, 175, 1),
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
          ).copyWith(
            secondary: const Color.fromRGBO(45, 161, 175, 1),
          ),
          fontFamily: 'Quicksand',
          textTheme: const TextTheme(
            displayLarge: AppTextStyles.title1,
            displayMedium: AppTextStyles.title2,
            displaySmall: AppTextStyles.title3,
            bodyLarge: AppTextStyles.primary,
            bodyMedium: AppTextStyles.primary,
            bodySmall: AppTextStyles.secondary,
            labelLarge: AppTextStyles.button,
            labelMedium: AppTextStyles.buttonSecondary,
            labelSmall: AppTextStyles.caption,
          ),
        ),
        initialRoute: '/splash', // Change initial route to splash
        routes: {
          '/splash': (context) => const SplashScreen(), // Add splash route
          '/': (context) => const AuthWrapper(),
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/complete_profile': (context) => const CompleteProfileScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/contacts': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return ContactsListScreen(filter: args?['filter'], mode: args?['action'], showAppBar: true,);
          },
          '/analytics': (context) => const AnalyticsScreen(),
          '/add_contact': (context) => const AddContactScreen(),
          '/import_contacts': (context) => const ImportContactsScreen(),
          '/notifications': (context) => const NotificationsScreen(showAppBar: false,),
          '/settings': (context) => const SettingsScreen(),
          '/groups': (context) => const GroupsListScreen(showAppBar: true,),
          '/edit_contact': (context) {
            final contactId = ModalRoute.of(context)!.settings.arguments as String;
            return EditContactScreen(contactId: contactId);
          },
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: Text('Page not found: ${settings.name}'),
              ),
            ),
          );
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// AuthWrapper to handle authentication state with FCM token storage
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _storeFCMTokenIfNeeded();
  }

  Future<void> _storeFCMTokenIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final apiService = ApiService();
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await apiService.updateUser({'fcmToken': token});
        print('FCM token stored for user: ${user.uid}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();
    
    if (firebaseUser != null) {
      return FutureBuilder<user.User>(
        future: _getUserProfile(firebaseUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(/* child: CircularProgressIndicator() */),
            );
          }
          
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          final userData = snapshot.data;
          
          // Check if profile is completed
          if (userData == null || !userData.profileCompleted) {
            return const CompleteProfileScreen();
          } else {
            return const DashboardScreen();
          }
        },
      );
    } else {
      return const WelcomeScreen();
    }
  }

  Future<user.User> _getUserProfile(String userId) async {
    final apiService = ApiService();
    user.User thisUser = await apiService.getUser();
    return thisUser;
  }
}