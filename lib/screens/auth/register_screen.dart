// register_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/user.dart' as thisUser; 
// import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'complete_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String _emailError = '';
  bool _isCheckingEmail = false;
  bool _emailHasBeenChecked = false;

  @override
  void initState() {
    super.initState();
    
    // Listen to email changes to clear error when user types
    _emailController.addListener(_clearEmailError);
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearEmailError);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearEmailError() {
    if (_emailError.isNotEmpty) {
      setState(() {
        _emailError = '';
        _emailHasBeenChecked = false;
      });
    }
  }

  // Method to check if email exists in Firestore
  Future<bool> _checkEmailAvailability(String email) async {
    if (email.isEmpty) return false;
    
    setState(() {
      _isCheckingEmail = true;
      _emailError = '';
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final emailExists = await apiService.checkEmailExists(email);
      
      setState(() {
        _emailHasBeenChecked = true;
        _isCheckingEmail = false;
      });
      
      return !emailExists; // Return true if email is available
    } catch (e) {
      setState(() {
        _isCheckingEmail = false;
      });
      return false;
    }
  }

  // Custom validator for email that checks availability
  String? _emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email address';
    }
    
    if (!value.contains('@') || !value.contains('.')) {
      return 'Please enter a valid email address';
    }
    
    // Only show duplicate error if we've checked and it exists
    if (_emailError.isNotEmpty && _emailHasBeenChecked) {
      return _emailError;
    }
    
    return null;
  }

  // Method to show email already exists dialog
  void _showEmailExistsDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Email Already Registered'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The email address "$email" is already associated with an account.'),
            const SizedBox(height: 16),
            const Text('Would you like to:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Use Different Email'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login screen
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3CB3E9),
            ),
            child: const Text('Go to Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Method to show email availability indicator
  Widget _buildEmailAvailabilityIndicator() {
    if (_isCheckingEmail) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff3CB3E9)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Checking email availability...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (_emailError.isNotEmpty && _emailHasBeenChecked) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Text(
              _emailError,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      );
    }
    
    if (_emailController.text.isNotEmpty && 
        _emailController.text.contains('@') && 
        _emailHasBeenChecked && 
        _emailError.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Email is available',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: GradientText( 
          text: 'NUDGE', 
          style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
          gradient: const LinearGradient(
            colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
        surfaceTintColor: Colors.transparent,
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
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Enter email address',
                  suffixIcon: _emailController.text.isNotEmpty && _emailController.text.contains('@')
                      ? IconButton(
                          icon: _isCheckingEmail
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xff3CB3E9)),
                                  ),
                                )
                              : Icon(
                                  _emailHasBeenChecked && _emailError.isEmpty
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  color: _emailHasBeenChecked && _emailError.isEmpty
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                          onPressed: () async {
                            if (_emailController.text.isNotEmpty && 
                                _emailController.text.contains('@')) {
                              final isAvailable = await _checkEmailAvailability(_emailController.text);
                              if (!isAvailable) {
                                setState(() {
                                  _emailError = 'This email is already registered';
                                  _emailHasBeenChecked = true;
                                });
                              } else {
                                setState(() {
                                  _emailError = '';
                                  _emailHasBeenChecked = true;
                                });
                              }
                            }
                          },
                        )
                      : null,
                  enabledBorder:  OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder:  OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff3CB3E9), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  errorBorder:  OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedErrorBorder:  OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: _emailValidator,
                onChanged: (value) {
                  // Clear the checked flag when user changes email
                  if (_emailHasBeenChecked) {
                    setState(() {
                      _emailHasBeenChecked = false;
                    });
                  }
                },
                onFieldSubmitted: (value) async {
                  if (value.isNotEmpty && value.contains('@')) {
                    await _checkEmailAvailability(value);
                  }
                },
              ),
              _buildEmailAvailabilityIndicator(),
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
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff3CB3E9), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
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
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Confirm your password',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff3CB3E9), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
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
                            // First check email availability
                            final email = _emailController.text.trim();
                            
                            setState(() => _isLoading = true);
                            
                            try {
                              // Check if email exists in Firestore
                              final emailExists = await apiService.checkEmailExists(email);
                              
                              if (emailExists) {
                                setState(() {
                                  _emailError = 'This email is already registered';
                                  _emailHasBeenChecked = true;
                                  _isLoading = false;
                                });
                                
                                // Show dialog to user
                                _showEmailExistsDialog(email);
                                return;
                              }
                              
                              // Try to register with Firebase Auth
                              final user = await authService.registerWithEmail(
                                email,
                                _passwordController.text,
                              );
                              
                              if (user != null) {
                                // Create initial user document
                                await apiService.addUser(thisUser.User(
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
                            } on FirebaseAuthException catch (e) {
                              // Handle Firebase Auth specific errors
                              String errorMessage = 'Registration failed. Please try again.';
                              
                              if (e.code == 'email-already-in-use') {
                                errorMessage = 'This email is already registered with another account.';
                                setState(() {
                                  _emailError = errorMessage;
                                  _emailHasBeenChecked = true;
                                });
                                
                                _showEmailExistsDialog(email);
                              } else if (e.code == 'weak-password') {
                                errorMessage = 'The password is too weak. Please use a stronger password.';
                              } else if (e.code == 'invalid-email') {
                                errorMessage = 'The email address is invalid.';
                              } else if (e.code == 'operation-not-allowed') {
                                errorMessage = 'Email/password accounts are not enabled.';
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setState(() => _isLoading = false);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setState(() => _isLoading = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff3CB3E9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                        // Check if user already exists in Firestore
                        final userData = await apiService.getUser();
                        if (userData.id == '') {
                          // Also check if email exists in Firestore (for consistency)
                          final emailExists = await apiService.checkEmailExists(user.email!);
                          
                          if (emailExists) {
                            // Show error and don't create duplicate
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('The email ${user.email} is already registered. Please log in.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() => _isLoading = false);
                            return;
                          }
                          
                          // Create initial user document
                          await apiService.addUser(thisUser.User(
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
                    } on FirebaseAuthException catch (e) {
                      String errorMessage = 'Google sign-up failed.';
                      if (e.code == 'account-exists-with-different-credential') {
                        errorMessage = 'This email is already registered with a different method.';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
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
                        // Check if user already exists in Firestore
                        final userData = await apiService.getUser();
                        if (userData.id == '') {
                          // Also check if email exists in Firestore
                          final emailExists = await apiService.checkEmailExists(user.email!);
                          
                          if (emailExists) {
                            // Show error and don't create duplicate
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('The email ${user.email} is already registered. Please log in.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() => _isLoading = false);
                            return;
                          }
                          
                          // Create initial user document
                          await apiService.addUser(thisUser.User(
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
                    } on FirebaseAuthException catch (e) {
                      String errorMessage = 'Apple sign-up failed.';
                      if (e.code == 'account-exists-with-different-credential') {
                        errorMessage = 'This email is already registered with a different method.';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
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