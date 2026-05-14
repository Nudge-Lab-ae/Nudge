import 'package:google_fonts/google_fonts.dart';
// register_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:nudge/models/user.dart' as thisUser;
import 'package:nudge/services/message_service.dart'; 
import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'complete_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/theme_provider.dart';

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

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

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
    _dismissKeyboard();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: Text('Email Already Registered', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The email address "$email" is already associated with an account.', 
              style: TextStyle(color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : Colors.black)),
            const SizedBox(height: 16),
            Text('Would you like to:', style: TextStyle(color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : Colors.black)),
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
              backgroundColor: theme.colorScheme.primary,
            ),
            child: Text('Go to Login', style: TextStyle(color: themeProvider.isDarkMode ? Colors.black : Colors.white)),
          ),
        ],
      ),
    );
  }

  // Method to show email availability indicator
  Widget _buildEmailAvailabilityIndicator() {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
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
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.lightPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking email availability...',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            Icon(Icons.error_outline, color: Color.fromARGB(255, 206, 37, 85), size: 16),
            const SizedBox(width: 8),
            Text(
              _emailError,
              style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 206, 37, 85)),
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
            Icon(Icons.check_circle, color: AppColors.success, size: 16),
            const SizedBox(width: 8),
            Text(
              'Email is available',
              style: TextStyle(fontSize: 12, color: AppColors.success),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    var size = MediaQuery.of(context).size;

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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  width: size.width,
                  child: Text(
                  'Create Your Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                ),
                const SizedBox(height: 30),
                
                // Email
                Text(
                  'Email',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onTap: () => _dismissKeyboard(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Enter email address',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    suffixIcon: _emailController.text.isNotEmpty && _emailController.text.contains('@')
                        ? IconButton(
                            icon: _isCheckingEmail
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.lightPrimary),
                                    ),
                                  )
                                : Icon(
                                    _emailHasBeenChecked && _emailError.isEmpty
                                        ? Icons.check_circle
                                        : Icons.check_circle_outline,
                                    color: _emailHasBeenChecked && _emailError.isEmpty
                                        ? AppColors.success
                                        : themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : Theme.of(context).colorScheme.outline,
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
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    fillColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                    filled: true,
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
                Text(
                  'Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  onTap: () => _dismissKeyboard(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    fillColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                    filled: true,
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
                Text(
                  'Confirm Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onTap: () => _dismissKeyboard(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Confirm your password',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    fillColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                    filled: true,
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
                  height: 55,
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                      : ElevatedButton(
                          onPressed: () async {
                            _dismissKeyboard();
                            if (_formKey.currentState!.validate()) {
                              // First check email availability
                              final email = _emailController.text.trim();
                              
                              setState(() => _isLoading = true);
                              
                              try {
                                // Check if email exists in Firestore
                                final emailExists = await apiService.checkEmailExists(email);
                                //print(email); //print(' is the email');
                                //print(emailExists); //print(' is emailExists');
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
                                    immersionLevel: 0.5,
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
                                  // ScaffoldMessenger.of(context).showSnackBar(
                                  //   const SnackBar(
                                  //     content: Text('Registration failed. Please try again.'),
                                  //   ),
                                  // );
                                  TopMessageService().showMessage(
                                    context: context,
                                    message: 'Registration failed. Please try again.',
                                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                                    icon: Icons.error,
                                  );
                                }
                              } on FirebaseAuthException catch (e) {
                                // Handle Firebase Auth specific errors
                                String errorMessage = 'Registration failed. Please try again.';
                                
                                if (e.code.contains('email-already-in-use')) {
                                  errorMessage = 'This email is already registered with another account.';
                                  setState(() {
                                    _emailError = errorMessage;
                                    _emailHasBeenChecked = true;
                                  });
                                  
                                  _showEmailExistsDialog(email);
                                } else if (e.code.contains('weak-password')) {
                                  errorMessage = 'The password is too weak. Please use a stronger password.';
                                } else if (e.code.contains('invalid-email')) {
                                  errorMessage = 'The email address is invalid.';
                                } else if (e.code.contains('operation-not-allowed')) {
                                  errorMessage = 'Email/password accounts are not enabled.';
                                }
                                
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   SnackBar(
                                //     content: Text(e.toString()),
                                //     backgroundColor: Color.fromARGB(255, 206, 37, 85),
                                //   ),
                                // );
                                TopMessageService().showMessage(
                                    context: context,
                                    message: e.toString(),
                                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                                    icon: Icons.error,
                                  );
                                setState(() => _isLoading = false);
                              } catch (e) {
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   SnackBar(
                                //     content: Text('Error: ${e.toString()}'),
                                //     backgroundColor: Color.fromARGB(255, 206, 37, 85),
                                //   ),
                                // );
                                TopMessageService().showMessage(
                                  context: context,
                                  message: 'Error: ${e.toString()}',
                                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                                  icon: Icons.error,
                                );
                                setState(() => _isLoading = false);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 18,
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
                
                // Google Sign Up
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      _dismissKeyboard();
                      setState(() => _isLoading = true);
                      try {
                        //print('register 1');
                        final user = await authService.signInWithGoogle();
                         //print('register 2');
                        if (user != null) {
                          // Check if user already exists in Firestore
                           //print('register 3');
                          final userData = await apiService.getUserRaw();
                          final userReallyExists = await apiService.userDataExists();
                           //print('register 4');
                          if (userData != null && userData.id != '') {
                            // Also check if email exists in Firestore (for consistency)
                             //print('register 5');
                            final emailExists = await apiService.checkEmailExists(user.email!);
                            

                            if (emailExists && userReallyExists) {
                              // Show error and don't create duplicate
                               //print('register 6');
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(
                              //     content: Text('The email ${user.email} is already registered. Please log in.'),
                              //     backgroundColor: Color.fromARGB(255, 206, 37, 85),
                              //   ),
                              // );
                              TopMessageService().showMessage(
                                context: context,
                                message: 'The email ${user.email} is already registered. Please log in.',
                                backgroundColor: Theme.of(context).colorScheme.tertiary,
                                icon: Icons.error,
                              );
                              setState(() => _isLoading = false);
                              return;
                            }
                             //print('register 7');
                            }
                           //print('register 8');
                          // Navigate to complete profile screen if profile is not completed
                          if (userData == null) {
                             //print('register 9');
                             // Create initial user document
                            await apiService.addUser(thisUser.User(
                              admin: false,
                              id: user.uid,
                              email: user.email!,
                              immersionLevel: 0.5,
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
                            
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const CompleteProfileScreen()),
                            );
                          }
                           //print('register 10');
                          // Otherwise, AuthWrapper will handle navigation to dashboard
                        }
                      } on FirebaseAuthException catch (e) {
                         //print('register 11');
                        String errorMessage = 'Google sign-up failed.';
                        if (e.code == 'account-exists-with-different-credential') {
                          errorMessage = 'This email is already registered with a different method.';
                        }
                        
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   SnackBar(
                        //     content: Text(errorMessage),
                        //     backgroundColor: Color.fromARGB(255, 206, 37, 85),
                        //   ),
                        // );
                        TopMessageService().showMessage(
                            context: context,
                            message: errorMessage,
                            backgroundColor: Theme.of(context).colorScheme.tertiary,
                            icon: Icons.error,
                          );
                      } catch (e) {
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   SnackBar(
                        //     content: Text('Error: ${e.toString()}'),
                        //     backgroundColor: Color.fromARGB(255, 206, 37, 85),
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
                    label: Text('Sign-up with Google', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
                
                // Apple Sign Up
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      _dismissKeyboard();
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
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(
                              //     content: Text('The email ${user.email} is already registered. Please log in.'),
                              //     backgroundColor: Color.fromARGB(255, 206, 37, 85),
                              //   ),
                              // );
                              TopMessageService().showMessage(
                                context: context,
                                message: 'The email ${user.email} is alrady registered. Please log in.',
                                backgroundColor: Theme.of(context).colorScheme.tertiary,
                                icon: Icons.error,
                              );
                              setState(() => _isLoading = false);
                              return;
                            }
                            
                            // Create initial user document
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
                        
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   SnackBar(
                        //     content: Text(errorMessage),
                        //     backgroundColor: Color.fromARGB(255, 206, 37, 85),
                        //   ),
                        // );
                        TopMessageService().showMessage(
                          context: context,
                          message: errorMessage,
                          backgroundColor: Theme.of(context).colorScheme.tertiary,
                          icon: Icons.error,
                        );
                      } catch (e) {
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   SnackBar(
                        //     content: Text('Error: ${e.toString()}'),
                        //     backgroundColor: Color.fromARGB(255, 206, 37, 85),
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
                    icon: Icon(Icons.apple, size: 30, color: Theme.of(context).colorScheme.onSurface),
                    label: Text('Sign-up with Apple', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}