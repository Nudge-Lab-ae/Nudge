import 'package:google_fonts/google_fonts.dart';
// lib/screens/auth/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/providers/admin_provider.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:nudge/models/user.dart' as thisUser;
import '../../providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: GradientText(
            text: 'NUDGE',
            style: GoogleFonts.plusJakartaSans(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 25),
            // Near-black gradient per Stitch mockups; inverted in dark mode
            // for legibility. Replaces the previous purple/blue gradient.
            gradient: LinearGradient(
              colors: themeProvider.isDarkMode
                  ? const [Color(0xFFE7E1DE), Color(0xFF968DA1)]
                  : const [Color(0xFF1A1A1A), Color(0xFF666666)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: theme.colorScheme.primary),
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Text(
              //   'CRAFTING CLOSER COMMUNITIES',
              //   style: TextStyle(
              //     fontSize: 20,
              //     fontWeight: FontWeight.w600,
              //     color: Theme.of(context).colorScheme.onSurface
              //   ),
              // ),
              // const SizedBox(height: 30),
              Text(
                'Email',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                onTap: () => _dismissKeyboard(),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  fillColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                onTap: () => _dismissKeyboard(),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  fillColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                  filled: true,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                    : ElevatedButton(
                        onPressed: () async {
                          _dismissKeyboard();
                          setState(() => _isLoading = true);
                          try {
                            final user = await authService.signInWithEmail(
                              _emailController.text,
                              _passwordController.text,
                            );
                            
                            if (user != null) {
                              thisUser.User theUser = await apiService.getUser();

                              if (theUser.phoneNumber != '' /* && user.phoneNumber!=null && user.phoneNumber!='' */) {
                                completeNavigation();
                              } else {
                                await apiService.addUser(thisUser.User(
                                  admin: false,
                                  id: user.uid,
                                  email: user.email!,
                                  username: user.displayName ?? '',
                                  phoneNumber: '',
                                  immersionLevel: 0.5,
                                  bio: '',
                                  description: '',
                                  photoUrl: user.photoURL ?? '',
                                  createdAt: DateTime.now(),
                                  nudges: [],
                                  goals: {},
                                  groups: [],
                                  profileCompleted: false,
                                  weeklyDigestEnabled: false
                                ));
                                completeProfile();
                              }
                            } else {
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   const SnackBar(
                              //     content: Text('Login failed. Please try again.'),
                              //   ),
                              // );
                              TopMessageService().showMessage(
                                context: context,
                                message: 'Login failed. Please try again.',
                                backgroundColor: Theme.of(context).colorScheme.tertiary,
                                icon: Icons.error,
                              );
                            }
                          } catch (e) {
                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   SnackBar(
                            //     content: Text('Error: ${e.toString()}'),
                            //   ),
                            // );
                            TopMessageService().showMessage(
                              context: context,
                              message: 'Error: ${e.toString()}',
                              backgroundColor: Theme.of(context).colorScheme.tertiary,
                              icon: Icons.error,
                            );
                          } finally {
                            setState(() => _isLoading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                'or',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    _dismissKeyboard();
                    setState(() => _isLoading = true);
                    //print('logging in with google');
                    try {
                      final user = await authService.signInWithGoogle();
                      if (user != null) {
                        thisUser.User theUser = await apiService.getUser();

                        final adminProvider = Provider.of<AdminProvider>(context, listen: false);
                        await adminProvider.checkAndCacheAdminStatus();

                        if (theUser.phoneNumber != '' /* && user.phoneNumber!=null && user.phoneNumber!='' */) {
                          completeNavigation();
                        } else {
                          await apiService.addUser(thisUser.User(
                            admin: false,
                            id: user.uid,
                            email: user.email!,
                            username: user.displayName ?? '',
                            phoneNumber: '',
                            immersionLevel: 0.5,
                            bio: '',
                            description: '',
                            photoUrl: user.photoURL ?? '',
                            createdAt: DateTime.now(),
                            nudges: [],
                            goals: {},
                            groups: [],
                            profileCompleted: false,
                            weeklyDigestEnabled: false
                          ));
                          completeProfile();
                        }
                      }
                    } catch (e) {
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(
                      //     content: Text('Error: ${e.toString()}'),
                      //   ),
                      // );
                      TopMessageService().showMessage(
                        context: context,
                        message: 'Error: ${e.toString()}',
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        icon: Icons.error,
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  icon: Icon(Icons.g_mobiledata, size: 30, color: Theme.of(context).colorScheme.onSurface),
                  label: Text('Sign in with Google', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : Theme.of(context).colorScheme.onSurface,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    _dismissKeyboard();
                    setState(() => _isLoading = true);
                    try {
                      await authService.modifiedAppleSignIn();
                      // Let AuthWrapper handle the navigation
                      FirebaseAuth _auth = FirebaseAuth.instance;
                      var user = _auth.currentUser;
                      if (user != null) {
                        thisUser.User theUser = await apiService.getUser();

                        if (theUser.phoneNumber != '' /* && user.phoneNumber!=null && user.phoneNumber!='' */) {
                          completeNavigation();
                        } else {
                          await apiService.addUser(thisUser.User(
                            admin: false,
                            id: user.uid,
                            immersionLevel: 0.5,
                            email: user.email!,
                            username: user.displayName ?? '',
                            phoneNumber: '',
                            bio: '',
                            description: '',
                            photoUrl: user.photoURL ?? '',
                            createdAt: DateTime.now(),
                            nudges: [],
                            goals: {},
                            groups: [],
                            profileCompleted: false,
                            weeklyDigestEnabled: false
                          ));
                          completeProfile();
                        }
                      }
                    } catch (e) {
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(
                      //     content: Text('Unable to Login. Please try again.'),
                      //   ),
                      // );
                      TopMessageService().showMessage(
                        context: context,
                        message: 'Unable to Login. Please try again.',
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        icon: Icons.error,
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  icon: Icon(Icons.apple, size: 30, color: Theme.of(context).colorScheme.onSurface),
                  label: Text('Sign in with Apple', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : Theme.of(context).colorScheme.onSurface,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text(
                    "Don't have an account? Register",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void completeNavigation() {
    _dismissKeyboard();
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  void completeProfile() {
    _dismissKeyboard();
    Navigator.pushReplacementNamed(context, '/complete_profile');
  }

  // Add this method to your LoginScreen class
  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Password reset email sent to $email'),
      //     duration: const Duration(seconds: 5),
      //   ),
      // );
      TopMessageService().showMessage(
          context: context,
          message: 'Password reset email sent to $email.',
          backgroundColor: AppColors.success,
          icon: Icons.check,
        );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled';
          break;
        default:
          errorMessage = 'Error sending reset email: ${e.message}';
      }
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text(errorMessage)),
      // );
      TopMessageService().showMessage(
          context: context,
          message: errorMessage,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          icon: Icons.error,
        );
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: ${e.toString()}')),
      // );
      TopMessageService().showMessage(
          context: context,
          message: 'Error: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          icon: Icons.error,
        );
    }
  }

  // Add this method to show the forgot password dialog
  void _showForgotPasswordDialog() {
    _dismissKeyboard();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    final emailController = TextEditingController(
      text: _emailController.text, // Pre-fill with entered email
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: Text('Reset Password', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(fontSize: 14, color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : Colors.black),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: emailController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : Colors.black),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty || !emailController.text.contains('@')) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('Please enter a valid email address')),
                // );
                TopMessageService().showMessage(
                  context: context,
                  message: 'Please enter a valid email address.',
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                  icon: Icons.error,
                );
                return;
              }
              
              Navigator.pop(context);
              await _resetPassword(emailController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
            ),
            child: Text('Send Reset Link', style: TextStyle(color: themeProvider.isDarkMode ? Colors.black : Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}