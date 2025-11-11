import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nudge/screens/admin/feedback_management_screen.dart';
import 'package:nudge/theme/text_styles.dart';
import '../../services/api_service.dart';
import 'package:nudge/models/user.dart' as user;
// import '../goals/set_goals_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackFormKey = GlobalKey<FormState>();
   bool _weeklyDigestEnabled = false;
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
  user.User? _currentUser;

  bool _isCropping = false;
  final _cropController = CropController();
  Uint8List? _imageBytes;
  String? _currentProfileImageUrl;
  
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
        _currentUser = userData;
        _currentProfileImageUrl = userData.photoUrl;
        _weeklyDigestEnabled = userData.weeklyDigestEnabled;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _isCropping = true;
      });
    }
  }

  // Future<void> _cropImage() async {
  //   if (_imageBytes == null) return;
    
  //   _cropController.crop();
  // }

  void _cancelCrop() {
    setState(() {
      _isCropping = false;
      _imageBytes = null;
    });
  }

  Future<String> _uploadImageToFirebase(Uint8List imageBytes, String fileName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imagesRef = storageRef.child('profile_pictures/$fileName');
      
      UploadTask uploadTask = imagesRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<void> _updateProfilePicture(Uint8List imageBytes) async {
    try {
      setState(() => _isChangingPassword = true);
      
      String uniqueID = _usernameController.text + DateTime.now().millisecondsSinceEpoch.toString();
      String imageUrl = await _uploadImageToFirebase(imageBytes, uniqueID);
      
      await ApiService().updateUser({
        'photoUrl': imageUrl,
        'updatedAt': DateTime.now(),
      });
      
      setState(() {
        _currentProfileImageUrl = imageUrl;
        _isCropping = false;
        _imageBytes = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile picture: $e')),
      );
    } finally {
      setState(() => _isChangingPassword = false);
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

 

Future<void> _updateWeeklyDigestSetting(bool enabled) async {
  try {
    await ApiService().updateUser({
      'weeklyDigestEnabled': enabled,
      'updatedAt': DateTime.now(),
    });
  } catch (e) {
    print('Error updating weekly digest setting: $e');
  }
}

void _showDeleteAccountConfirmation() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Account'),
      content: const Text(
        'This action cannot be undone. All your data, contacts, groups, and settings will be permanently deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _deleteAccount,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete Account'),
        ),
      ],
    ),
  );
}

Future<void> _deleteAccount() async {
  try {
    // Close dialog
    Navigator.pop(context);
    
    // Show loading
    setState(() => _isChangingPassword = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Delete user data from Firestore first
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      
      // Delete user authentication
      await user.delete();
      
      // Navigate to login
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );
    }
  } catch (e) {
    setState(() => _isChangingPassword = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error deleting account: $e')),
    );
  }
}

 Widget _buildProfilePictureSection() {
    return Column(
      children: [
        if (_isCropping) ...[
          const SizedBox(height: 20),
          const Text(
            'Crop Your Profile Picture',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Adjust the square to frame your photo',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _imageBytes != null
                  ? Crop(
                      image: _imageBytes!,
                      controller: _cropController,
                      aspectRatio: 1,
                      onCropped: (result) {
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            _updateProfilePicture(croppedImage);
                          case CropFailure(:final cause):
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Error'),
                                content: Text('Failed to crop image: $cause'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                        }
                      },
                      withCircleUi: true,
                      baseColor: Colors.blue.shade900,
                      maskColor: Colors.white.withAlpha(100),
                      cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: Colors.blue),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelCrop,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _currentProfileImageUrl != null && _currentProfileImageUrl!.isNotEmpty
                        ? NetworkImage(_currentProfileImageUrl!)
                        : null,
                    backgroundColor: const Color.fromRGBO(45, 161, 175, 0.1),
                    child: _currentProfileImageUrl == null || _currentProfileImageUrl!.isEmpty
                        ? const Icon(Icons.person, size: 40, color: Color.fromRGBO(45, 161, 175, 1))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color.fromRGBO(45, 161, 175, 1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap to change profile picture',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 30),
        ],
      ],
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
        title: Text('NUDGE', style: AppTextStyles.title3.copyWith(color: Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono'),),
                  centerTitle: true,
                  iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
                  backgroundColor: Colors.white,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.white),
        //   onPressed: () => Navigator.pop(context),
        // ),
      ),
      body: _isCropping 
          ? _buildProfilePictureSection()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

             _buildProfilePictureSection(),
            // Profile Settings Section
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 Padding(
                  padding: EdgeInsets.only(left: 50),
                  child:  const Text(
                    'Adjust Settings',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff000000),
                    ),
                  ),
                  ),
                  const SizedBox(height: 35),
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

                   // Weekly Digest Section
            const SizedBox(height: 30),
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Digest',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Receive weekly summary of relationships needing attention',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
               Container(
                width: 100,
                child:  Switch(
                  value: _weeklyDigestEnabled,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Color(0xffdddddd),
                  onChanged: (value) {
                    setState(() {
                      _weeklyDigestEnabled = value;
                    });
                    _updateWeeklyDigestSetting(value);
                  },
                  activeColor: const Color.fromRGBO(45, 161, 175, 1),
                ),
               )
              ],
            ),

                  
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
            // const Text(
            //   'Interaction Goals',
            //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            // ),
            // const SizedBox(height: 15),
            // SizedBox(
            //   width: double.infinity,
            //   height: 50,
            //   child: OutlinedButton(
            //     onPressed: () {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(builder: (context) => const SetGoalsScreen(isFromSettings: true)),
            //       );
            //     },
            //     style: OutlinedButton.styleFrom(
            //       foregroundColor: const Color.fromRGBO(45, 161, 175, 1),
            //       side: const BorderSide(color: Color.fromRGBO(45, 161, 175, 1)),
            //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            //     ),
            //     child: const Text('Go to Interaction Goals'),
            //   ),
            // ),

          // Add after General section in settings_screen.dart

           
            // Delete Account Section
            const SizedBox(height: 40),
            const Text(
              'Account Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _showDeleteAccountConfirmation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Delete Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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

                  const SizedBox(height: 30),

                  // Feedback Management Section (for admins)
                  _currentUser!.admin
                  ?Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feedback Management',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'View and manage user feedback submissions',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FeedbackManagementScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Manage Feedback',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ):Center(),
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