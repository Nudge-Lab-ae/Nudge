// lib/screens/auth/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
// import '../../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    // final apiService = Provider.of<ApiService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
         title: GradientText( text: 'NUDGE', style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
              gradient: const LinearGradient(
                colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        ),
        //  Text('NUDGE', style: AppTextStyles.title2.copyWith(color: Color(0xff3CB3E9), fontFamily: 'RobotoMono'),),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xff3CB3E9)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'CRAFTING CLOSER COMMUNITIES',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff555555)
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'EMAIL',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xff555555),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                // Optional: to show border even when there's an error
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'PASSWORD',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xff555555)
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter your password',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                // Optional: to show border even when there's an error
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10)
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xff3CB3E9),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () async {
                        setState(() => _isLoading = true);
                        try {
                          final user = await authService.signInWithEmail(
                            _emailController.text,
                            _passwordController.text,
                          );
                          
                          if (user != null) {
                            // Let AuthWrapper handle the navigation
                            // It will automatically check profile completion and navigate appropriately
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Login failed. Please try again.'),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                            ),
                          );
                        } finally {
                          setState(() => _isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff3CB3E9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Sign In',
                        style: AppTextStyles.button.copyWith(color: Colors.white)
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'or',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
               onPressed: () async {
                  setState(() => _isLoading = true);
                  print('logging in with google');
                  try {
                    final user = await authService.signInWithGoogle();
                    if (user != null) {
                      // Let AuthWrapper handle the navigation
                      if (user.email !=null && user.phoneNumber!=null && user.phoneNumber!='') {
                        completeNavigation();
                      } else {
                        completeProfile();
                      }
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                      ),
                    );
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                icon: const Icon(Icons.g_mobiledata, size: 30),
                label: const Text('Sign in with Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    await authService.modifiedAppleSignIn();
                    // Let AuthWrapper handle the navigation
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unable to Login. Please try again.'),
                      ),
                    );
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                icon: const Icon(Icons.apple, size: 30),
                label: const Text('Sign in with Apple'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text(
                  "Don't have an account? Register",
                  style: TextStyle(
                    color: Color(0xff3CB3E9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void completeNavigation() {
  // Don't navigate here - let AuthWrapper handle it
  // The AuthWrapper will automatically redirect to dashboard
    // Future.delayed(Duration(seconds: 1)).then((value) {
    //   Navigator.pop(context);
    // });
    Navigator.pushReplacementNamed(context, '/dashboard');
}

void completeProfile() {
  // Navigate to complete profile screen
  Navigator.pushReplacementNamed(context, '/complete_profile');
}

  // Add this method to your LoginScreen class
  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          duration: const Duration(seconds: 5),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // Add this method to show the forgot password dialog
  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(
      text: _emailController.text, // Pre-fill with entered email
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address')),
                );
                return;
              }
              
              Navigator.pop(context);
              await _resetPassword(emailController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3CB3E9),
            ),
            child: const Text('Send Reset Link', style: TextStyle(color: Colors.white),),
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