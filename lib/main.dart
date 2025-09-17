// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nudge/firebase_options.dart';
import 'package:nudge/screens/analytics/analytics_screen.dart';
import 'package:nudge/screens/auth/complete_profile_screen.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/contacts/contacts_list_screen.dart';
import 'screens/contacts/add_contact_screen.dart';
// import 'screens/contacts/contact_detail_screen.dart';
import 'screens/contacts/import_contacts_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/groups/groups_list_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, name: "NudgeApp"
  );
  final nudgeService = NudgeService();
  await nudgeService.initialize();

  runApp(const NudgeApp());
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
       theme: ThemeData(
          primaryColor: const Color.fromRGBO(45, 161, 175, 1),
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
          ).copyWith(
            secondary: const Color.fromRGBO(45, 161, 175, 1),
          ),
          fontFamily: 'Montserrat',
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
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/complete_profile': (context) => const CompleteProfileScreen(),
          '/dashboard': (context) => const DashboardScreen(),
           '/contacts': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return ContactsListScreen(filter: args?['filter']);
            },
          '/analytics': (context) => const AnalyticsScreen(),
          '/add_contact': (context) => const AddContactScreen(),
          '/import_contacts': (context) => const ImportContactsScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/groups': (context) => const GroupsListScreen(),
          '/edit_contact': (context) {
              final contactId = ModalRoute.of(context)!.settings.arguments as String;
              return EditContactScreen(contactId: contactId);
            },
        },
        onGenerateRoute: (settings) {
          // Handle routes with parameters

          // if (settings.name == '/contact_detail') {
          //   final contactId = settings.arguments as String;
          //   return MaterialPageRoute(
          //     builder: (context) => ContactDetailScreen(contactId: contactId),
          //   );
          // }
          
          // Handle unknown routes
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

// AuthWrapper to handle authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    
    if (user != null) {
      return const DashboardScreen();
    } else {
      return const WelcomeScreen();
      // return const DashboardScreen();
    }
  }
}