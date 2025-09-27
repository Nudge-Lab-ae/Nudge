import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nudge/theme/text_styles.dart';
import '../../services/api_service.dart';
import '../goals/set_goals_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackFormKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _feedbackTypeController;
  late TextEditingController _feedbackMessageController;
  
  bool _isLoading = true;
  bool _isEmailPasswordUser = false;
  bool _isChangingPassword = false;
  bool _isSubmittingFeedback = false;
  
  // Feedback types
  final List<String> _feedbackTypes = [
    'Feedback',
    'Bug Report',
    'Feature Request',
    'General Inquiry',
    'Complaint'
  ];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _feedbackTypeController = TextEditingController(text: 'Feedback');
    _feedbackMessageController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await ApiService().getUser();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Check if user signed in with email/password
      if (currentUser != null) {
        final providers = currentUser.providerData;
        _isEmailPasswordUser = providers.any((provider) => 
          provider.providerId == 'password'
        );
      }
      
      setState(() {
        _usernameController.text = userData.username;
        _emailController.text = userData.email;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isChangingPassword = true;
      });
      
      try {
        // Update user profile data
        await ApiService().updateUser({
          'username': _usernameController.text,
          'email': _emailController.text,
          'updatedAt': DateTime.now(),
        });

        // Update password if provided and user is email/password
        if (_isEmailPasswordUser && _newPasswordController.text.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Reauthenticate user before changing password
            final credential = EmailAuthProvider.credential(
              email: user.email!,
              password: _oldPasswordController.text,
            );
            
            await user.reauthenticateWithCredential(credential);
            await user.updatePassword(_newPasswordController.text);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        
        // Clear password fields
        _oldPasswordController.clear();
        _newPasswordController.clear();
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'wrong-password':
            errorMessage = 'The current password is incorrect.';
            break;
          case 'weak-password':
            errorMessage = 'The new password is too weak.';
            break;
          default:
            errorMessage = 'Error updating profile: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      } finally {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (_feedbackFormKey.currentState!.validate()) {
      setState(() {
        _isSubmittingFeedback = true;
      });

      try {
        await ApiService().submitFeedback(
          message: _feedbackMessageController.text,
          type: _feedbackTypeController.text,
          additionalData: {
            'screen': 'SettingsScreen',
            'appSection': 'feedback_form',
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );

        // Clear feedback form
        _feedbackMessageController.clear();
        _feedbackTypeController.text = 'Feedback';

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
        );
      } finally {
        setState(() {
          _isSubmittingFeedback = false;
        });
      }
    }
  }

  void _showFeedbackTypeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Feedback Type'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _feedbackTypes.length,
              itemBuilder: (context, index) {
                final type = _feedbackTypes[index];
                return ListTile(
                  title: Text(type, style: TextStyle(fontWeight: FontWeight.w600),),
                  onTap: () {
                    setState(() {
                      _feedbackTypeController.text = type;
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.title2.copyWith(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Settings Section
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'You are on an exclusive access subscription.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  
                  const Text(
                    'General',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  const Text(
                    'Username',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  const Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    enabled: false,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  
                  // Only show password fields for email/password users
                  if (_isEmailPasswordUser) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    const Text(
                      'Current Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter your current password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (_newPasswordController.text.isNotEmpty && 
                            (value == null || value.isEmpty)) {
                          return 'Current password is required to set a new password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    const Text(
                      'New Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter your new password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return 'Password must be at least 6 characters long';
                        }
                        return null;
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isChangingPassword
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _updateUserData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'Confirm Changes',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Interaction Goals Section
            const Text(
              'Interaction Goals',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SetGoalsScreen(isFromSettings: true)),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color.fromRGBO(45, 161, 175, 1),
                  side: const BorderSide(color: Color.fromRGBO(45, 161, 175, 1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Go to Interaction Goals'),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Feedback Section
            Form(
              key: _feedbackFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Help / Feedback',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  
                  const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showFeedbackTypeDialog,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _feedbackTypeController,
                        decoration: InputDecoration(
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a feedback type';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _feedbackMessageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Please share your feedback, suggestions, or issues...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your feedback';
                      }
                      if (value.length < 10) {
                        return 'Please provide more details (at least 10 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isSubmittingFeedback
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitFeedback,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'Submit Feedback',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _feedbackTypeController.dispose();
    _feedbackMessageController.dispose();
    super.dispose();
  }
}