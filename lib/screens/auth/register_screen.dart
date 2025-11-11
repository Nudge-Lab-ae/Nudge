// register_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/user.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'complete_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('NUDGE', style: AppTextStyles.title3.copyWith(color: Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono'),),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Create Your Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Email
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
                  hintText: 'Enter email address',
                  // border: OutlineInputBorder(
                  //   borderRadius: BorderRadius.circular(10),
                  // ),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Password
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
                  hintText: 'Enter password',
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Confirm Password
              const Text(
                'Confirm Password',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirm your password',
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              
              // Register Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isLoading = true);
                            try {
                              final user = await authService.registerWithEmail(
                                _emailController.text,
                                _passwordController.text,
                              );
                              
                              if (user != null) {
                                // Create initial user document
                                await apiService.addUser(User(
                                  id: user.uid,
                                  admin: false,
                                  email: user.email!,
                                  username: '',
                                  phoneNumber: '',
                                  bio: '',
                                  description: '',
                                  photoUrl: '',
                                  createdAt: DateTime.now(),
                                  nudges: [],
                                  goals: {},
                                  groups: [],
                                  profileCompleted: false,
                                  weeklyDigestEnabled: false,
                                ));
                                
                                // Navigate to complete profile screen
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CompleteProfileScreen()),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Registration failed. Please try again.'),
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
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white
                          ),
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
              
              // Google Sign Up
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    try {
                      final user = await authService.signInWithGoogle();
                      if (user != null) {
                        // Check if user already exists
                        final userData = await apiService.getUser();
                        if (userData.id == '') {
                          // Create initial user document
                          await apiService.addUser(User(
                            admin: false,
                            id: user.uid,
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
                        }
                        
                        // Navigate to complete profile screen if profile is not completed
                        if (userData.id == '' || !userData.profileCompleted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const CompleteProfileScreen()),
                          );
                        }
                        // Otherwise, AuthWrapper will handle navigation to dashboard
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
                  label: const Text('Sign-up with Google'),
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
              
              // Apple Sign Up
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    try {
                      final user = await authService.modifiedAppleSignIn();
                      if (user != null) {
                        // Check if user already exists
                        final userData = await apiService.getUser();
                        if (userData.id == '') {
                          // Create initial user document
                          await apiService.addUser(User(
                            admin: false,
                            id: user.uid,
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
                            weeklyDigestEnabled: false,
                          ));
                        }
                        
                        // Navigate to complete profile screen if profile is not completed
                        if (userData.id == '' || !userData.profileCompleted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const CompleteProfileScreen()),
                          );
                        }
                        // Otherwise, AuthWrapper will handle navigation to dashboard
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
                  icon: const Icon(Icons.apple, size: 30),
                  label: const Text('Sign-up with Apple'),
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
            ],
          ),
        ),
      ),
    );
  }
}