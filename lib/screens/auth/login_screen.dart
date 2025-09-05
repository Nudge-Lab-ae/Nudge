// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
// import '../dashboard/dashboard_screen.dart';

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
    // Now we can safely access AuthService because it's provided at the root level
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title:  Text('NUDGE', style: AppTextStyles.title2.copyWith(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
        leading: IconButton(onPressed: () {
          Navigator.pop(context);
        } , icon: Icon(Icons.arrow_back, color: Colors.white,)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Crafting Closer Communities',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Email',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Password',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter your password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
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
                        final user = await authService.signInWithEmail(
                          _emailController.text,
                          _passwordController.text,
                        );
                        setState(() => _isLoading = false);
                        
                        if (user != null) {
                          // Navigation is handled automatically by AuthWrapper
                          // No need to navigate manually
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Login failed. Please try again.'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
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
                  final user = await authService.signInWithGoogle();
                  setState(() => _isLoading = false);
                  
                  if (user != null) {
                    // Navigation handled by AuthWrapper
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
                  final user = await authService.signInWithApple();
                  setState(() => _isLoading = false);
                  
                  if (user != null) {
                    // Navigation handled by AuthWrapper
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
            const SizedBox(height: 15),
            // SizedBox(
            //   width: double.infinity,
            //   height: 50,
            //   child: OutlinedButton.icon(
            //     onPressed: () async {
            //       setState(() => _isLoading = true);
            //       final user = await authService.signInWithFacebook();
            //       setState(() => _isLoading = false);
                  
            //       if (user != null) {
            //         // Navigation handled by AuthWrapper
            //       }
            //     },
            //     icon: const Icon(Icons.facebook, size: 30),
            //     label: const Text('Sign in with Facebook'),
            //     style: OutlinedButton.styleFrom(
            //       foregroundColor: Colors.black,
            //       side: BorderSide(
            //         color: Colors.grey.shade300,
            //       ),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(10),
            //       ),
            //     ),
            //   ),
            // ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text(
                  "Don't have an account? Register",
                  style: TextStyle(
                    color: Color.fromRGBO(37, 150, 190, 1),
                  ),
                ),
              ),
            ),
          ],
        ),
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