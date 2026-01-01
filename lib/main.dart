import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nudge/firebase_options.dart';
import 'package:nudge/helpers/auth_refresh_helper.dart';
import 'package:nudge/helpers/deletion_retry_helper.dart';
import 'package:nudge/screens/analytics/analytics_screen.dart';
import 'package:nudge/screens/auth/complete_profile_screen.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';
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

// Create a GlobalKey for navigator to handle notifications when app is in background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Add this global variable to track notification navigation
String? _pendingNotificationRoute;

// Initialize flutter_local_notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Global function to handle notification navigation
void handleNotificationNavigation(Map<String, dynamic> payload) {
  print('handleNotificationNavigation called with payload: $payload');
  
  // Force navigation to dashboard with notifications tab
  _pendingNotificationRoute = '/dashboard?tab=notifications';
  print('Pending notification route set to: $_pendingNotificationRoute');
  
  // If navigator is ready, navigate immediately
  if (navigatorKey.currentState != null) {
    _processPendingNotification();
  }
}

// Process pending notification
void _processPendingNotification() {
  if (_pendingNotificationRoute != null && navigatorKey.currentState != null) {
    print('Processing pending notification route: $_pendingNotificationRoute');
    
    // Navigate to dashboard with notifications tab
    if (_pendingNotificationRoute == '/dashboard?tab=notifications') {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
        arguments: {'initialTab': 3}, // 3 is the index for notifications in bottom nav
      );
    }
    
    _pendingNotificationRoute = null;
  }
}

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
  
  WidgetsBinding.instance.debugShowWidgetInspectorOverrideNotifier.value = false;
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
    print('Notification tapped - navigating to notifications');
    navigateToNotificationsScreen();
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
    navigateToNotificationsScreen();
  });

  // Handle notification when app is terminated
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    print('App opened from terminated state via notification');
    navigateToNotificationsScreen();
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
      _handleTerminatedMessage(message);
    }
  });
  
  // Handle messages when app is in foreground
  FirebaseMessaging.onMessage.listen((message) {
    print('Foreground message: ${message.data}');
    _showLocalNotification(message);
  });
  
  // Handle when app is in background but not terminated
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print('App opened from background with message: ${message.data}');
    _handleBackgroundMessage(message);
  });
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
    message.notification?.title ?? 'Connection Nudge 💫',
    message.notification?.body ?? 'Time to connect!',
    platformChannelSpecifics,
    payload: _buildNotificationPayload(message.data),
  );
}

void navigateToNotificationsScreen() {
  print('Direct navigation to notifications screen');
  
  if (navigatorKey.currentState != null) {
    // Clear all existing routes and go to dashboard with notifications tab
    navigatorKey.currentState!.pushNamedAndRemoveUntil(
      '/dashboard',
      (route) => false,
      arguments: {'initialTab': 3},
    );
  } else {
    print('Navigator not ready, storing for later');
    _pendingNotificationRoute = '/dashboard?tab=notifications';
  }
}

String _buildNotificationPayload(Map<String, dynamic> messageData) {
  // Simplified payload - just force notifications tab
  final payload = {
    'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    'screen': 'notifications',
  };
  
  return payload.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join('&');
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

// void _handleNotificationTap(String? payload) {
//   print('Notification tapped - forcing to notifications screen');
  
//   // Always navigate to notifications screen
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     if (navigatorKey.currentState != null) {
//       navigatorKey.currentState!.pushNamedAndRemoveUntil(
//         '/dashboard',
//         (route) => false,
//         arguments: {'initialTab': 3}, // 3 is notifications tab index
//       );
//     }
//   });
// }

void _handleBackgroundMessage(RemoteMessage message) {
  print('Background message - forcing to notifications screen');
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
        arguments: {'initialTab': 3},
      );
    }
  });
}

void _handleTerminatedMessage(RemoteMessage message) {
  print('Terminated message - forcing to notifications screen');
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
        arguments: {'initialTab': 3},
      );
    }
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
          primaryColor: Color(0xFFF9FAFB),
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
          ).copyWith(
            secondary: Color(0xFFF9FAFB)
          ),
          fontFamily: 'OpenSans',
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
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/': (context) => const AuthWrapper(),
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/complete_profile': (context) => const CompleteProfileScreen(),
          '/dashboard': (context) {
            // Check for notification navigation argument
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return DashboardScreen(initialTab: args?['initialTab'] ?? 0);
          },
          '/contacts': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return ContactsListScreen(filter: args?['filter'], mode: args?['action'], showAppBar: true, hideButton: (){},);
          },
          '/analytics': (context) => const AnalyticsScreen(),
          '/add_contact': (context) => const AddContactScreen(),
          '/import_contacts': (context) => const ImportContactsScreen(),
          '/notifications': (context) => const NotificationsScreen(showAppBar: true),
          '/settings': (context) => const SettingsScreen(),
          '/groups': (context) => const GroupsListScreen(showAppBar: true,),
          '/edit_contact': (context) {
            final contactId = ModalRoute.of(context)!.settings.arguments as String;
            return EditContactScreen(contactId: contactId);
          },
          '/feedback_forum': (context) => const FeedbackForumScreen(),
        },
        builder: (context, child) {
          // Process any pending notification when the app is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pendingNotificationRoute != null && navigatorKey.currentState != null) {
              print('Processing pending notification route on app build');
              navigateToNotificationsScreen();
              _pendingNotificationRoute = null;
            }
          });
          return child!;
        },
        onGenerateRoute: (settings) {
          // If notification route is detected, always go to dashboard with notifications tab
          if (settings.name == '/notifications' || 
              settings.name?.contains('notification') == true) {
            return MaterialPageRoute(
              builder: (context) => DashboardScreen(initialTab: 3),
            );
          }
          
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String _checkingStatus = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _storeFCMTokenIfNeeded();
      await _checkDeletionRetry();
      await _checkUserData();
    } catch (e) {
      print('Error initializing AuthWrapper: $e');
    } finally {
      setState(() {
        _initialized = true;
      });
    }
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

  Future<void> _checkUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _checkingStatus = 'Checking user data...';
      });
      
      try {
        final apiService = ApiService();
        await apiService.ensureUserDocumentCompleteness(user.uid);
        print('User data check completed');
      } catch (e) {
        print('Error checking user data: $e');
      } finally {
        setState(() {
          _checkingStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();
    
    // Show loading screen until initialized
    if (!_initialized) {
      return _buildLoadingScreen();
    }
    
    if (firebaseUser != null) {
      return _buildAuthenticatedScreen(firebaseUser);
    } else {
      // User is not authenticated, go to welcome screen
      return const WelcomeScreen();
    }
  }

  Future<void> _checkDeletionRetry() async {
    final hasRetry = await DeletionRetryHelper.hasPendingDeletionRetry();
    if (hasRetry && mounted) {
      await DeletionRetryHelper.clearDeletionRetryIntent();
      await DeletionRetryHelper.setShowRetryPrompt(true);
      
      // Navigate to dashboard first to establish proper state
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          Navigator.pushNamed(context, '/dashboard');
        }
      });
    }
  }

  Widget _buildAuthenticatedScreen(User firebaseUser) {
    // Always refresh auth state when building authenticated screen
    Future.microtask(() async {
      await AuthRefreshHelper.refreshAuthState();
    });
    
    return FutureBuilder<user.User>(
      future: _getUserProfile(firebaseUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading profile: ${snapshot.error}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Force reload
                      setState(() {});
                    },
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
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff3CB3E9)),
            ),
            const SizedBox(height: 20),
            Text(
              _checkingStatus.isNotEmpty ? _checkingStatus : 'Loading...',
              style: const TextStyle(
                color: Color(0xff3CB3E9),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<user.User> _getUserProfile(String userId) async {
    final apiService = ApiService();
    return await apiService.getUser();
  }
}