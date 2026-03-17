// settings_screen.dart - Updated with theme toggle and Feedback Forum link
import 'dart:io';
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nudge/helpers/deletion_retry_helper.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/screens/admin/feedback_management_screen.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/widgets/screen_tracker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'package:nudge/models/user.dart' as user; 


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackFormKey = GlobalKey<FormState>();
  // bool _weeklyDigestEnabled = true;
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
  bool deleting = false;

  bool _isCropping = false;
  final _cropController = CropController();
  Uint8List? _imageBytes;
  String? _currentProfileImageUrl;

  final FocusNode _feedbackMessageFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _oldPasswordFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  
  final List<String> _feedbackTypes = [
    'Feedback / Inquiry',
    'Bug Report',
    'Feature Request',
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
    _checkForRetryPrompt();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await ApiService().getUser();
      final currentUser = FirebaseAuth.instance.currentUser;
      
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
        // _weeklyDigestEnabled = userData.weeklyDigestEnabled;
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

  Future<void> _cropImage() async {
    if (_imageBytes == null) return;
    
    _cropController.crop();
  }

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
      
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Profile picture updated successfully')),
      // );
      TopMessageService().showMessage(
        context: context,
        message: 'Profile picture updated successfully.',
        backgroundColor: Colors.green,
        icon: Icons.check,
      );
    } catch (e) {
      TopMessageService().showMessage(
          context: context,
          message: 'Failed to update profile picture.',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
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
        await ApiService().updateUser({
          'username': _usernameController.text,
          'email': _emailController.text,
          'updatedAt': DateTime.now(),
        });

        if (_isEmailPasswordUser && _newPasswordController.text.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final credential = EmailAuthProvider.credential(
              email: user.email!,
              password: _oldPasswordController.text,
            );
            
            await user.reauthenticateWithCredential(credential);
            await user.updatePassword(_newPasswordController.text);
          }
        }

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Profile updated successfully')),
        // );
        TopMessageService().showMessage(
          context: context,
          message: 'Profile updated successfully.',
          backgroundColor: Colors.green,
          icon: Icons.check,
        );
        
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
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(errorMessage)),
        // );
        TopMessageService().showMessage(
          context: context,
          message: errorMessage,
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
        );
      } catch (e) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error updating profile: $e')),
        // );
        TopMessageService().showMessage(
          context: context,
          message: 'Error updating profile: $e',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
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
        final screenName = ScreenTracker.getCurrentScreen(context);
        await ApiService().submitFeedback(
          message: _feedbackMessageController.text,
          type: _feedbackTypeController.text,
          additionalData: {
            'screen': 'SettingsScreen',
            'appSection': 'feedback_form',
          },
          screenName: screenName,
        );

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Thank you for your feedback!')),
        // );

        TopMessageService().showMessage(
          context: context,
          message: 'Thank you for your feedback!',
          backgroundColor: Colors.green,
          icon: Icons.check,
        );

        _feedbackMessageController.clear();
        _feedbackTypeController.text = 'Feedback';

      } catch (e) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error submitting feedback: $e')),
        // );
        TopMessageService().showMessage(
          context: context,
          message: 'Error submitting feedback: $e',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
        );
      } finally {
        setState(() {
          _isSubmittingFeedback = false;
        });
      }
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Widget _buildFeedbackForm(ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Form(
      key: _feedbackFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help / Feedback',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
          ),
          const SizedBox(height: 15),
          
          Text('Type', style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              _dismissKeyboard();
              _showFeedbackTypeDialog(themeProvider);
            },
            child: AbsorbPointer(
              child: TextFormField(
                controller: _feedbackTypeController,
                style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10)
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(10)
                  ),
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
          
          Text('Comments', style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
          const SizedBox(height: 8),
          TextFormField(
            controller: _feedbackMessageController,
            focusNode: _feedbackMessageFocusNode,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onEditingComplete: () {
              _dismissKeyboard();
            },
            style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Please share your feedback, suggestions, or issues...',
              hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff555555)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(10)
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(10)
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 1),
                borderRadius: BorderRadius.circular(10)
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 2),
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
                    onPressed: () {
                      _dismissKeyboard();
                      _submitFeedback();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Center(
                      child: Text(
                      'SUBMIT FEEDBACK',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode?Colors.black:Colors.white),
                    ),
                    )
                  ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackTypeDialog(ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('SELECT FEEDBACK TYPE', style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
          backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _feedbackTypes.length,
              itemBuilder: (context, index) {
                final type = _feedbackTypes[index];
                return ListTile(
                  title: Text(type, style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
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

  // Future<void> _updateWeeklyDigestSetting(bool enabled) async {
  //   try {
  //     await ApiService().updateUser({
  //       'weeklyDigestEnabled': enabled,
  //       'updatedAt': DateTime.now(),
  //     });
  //   } catch (e) {
  //     print('Error updating weekly digest setting: $e');
  //   }
  // }

  void _showDeleteAccountConfirmation(AuthService authService, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('DELETE ACCOUNT', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
        content: const Text(
          'This action cannot be undone. All your data, contacts, groups, and settings will be permanently deleted.',
        ),
        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: deleting ? null : () {
              Navigator.pop(context);
              deleteUser(authService);
            },
            style: TextButton.styleFrom(
              foregroundColor: deleting ? Colors.grey : Colors.red,
            ),
            child: Text(deleting ? 'Deleting...' : 'Delete Account'),
          ),
        ],
      ),
    );
  }

  void showDeletedMessage() {
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Row(
    //       children: [
    //         Expanded(
    //           child: Column(
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             mainAxisSize: MainAxisSize.min,
    //             children: [
    //               const Text(
    //                 'Deleted Account!',
    //                 style: TextStyle(
    //                   fontWeight: FontWeight.bold,
    //                   color: Colors.white,
    //                 ),
    //               ),
    //               Text(
    //                 'You have successfully deleted your account. Any data previously recorded has been removed.',
    //                 style: const TextStyle(color: Colors.white70, fontSize: 12),
    //               ),
    //             ],
    //           ),
    //         ),
    //       ],
    //     ),
    //     backgroundColor: Colors.green,
    //     duration: const Duration(seconds: 4),
    //   ),
    // );

    TopMessageService().showCustomContent(
      context: context,
      backgroundColor: Colors.green,
      height: 150,
      customContent: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Deleted Account!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18
                    ),
                  ),
                  Text(
                    'You have successfully deleted your account. Any data previously recorded has been removed.',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Future<void> _checkForRetryPrompt() async {
    if (await DeletionRetryHelper.shouldShowRetryPrompt()) {
      await DeletionRetryHelper.clearRetryPromptFlag();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRetryPrompt();
      });
    }
  }

  void _showRetryPrompt() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Try Again'),
        content: const Text(
          'Please try deleting your account again. The app state has been refreshed.',
        ),
        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> deleteUser(AuthService authService) async {
    FirebaseAuth _auth = FirebaseAuth.instance;
    ApiService apiService = ApiService();
    User? currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('No user logged in')),
      // );
       TopMessageService().showMessage(
          context: context,
          message: 'No user logged in.',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
        );
      return false;
    }
    
    setState(() {
      deleting = true;
    });
    
    try {
      await currentUser.getIdToken(true);
      apiService.cancelUserNotifications();
      
      bool deleted = await apiService.deleteUser();
      
      if (!deleted) return false;
      
      await _auth.signOut();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/welcome', 
          (route) => false
        );
      });

      showDeletedMessage();
      
      return true;
    } catch (error) {
      print('Error deleting user: $error');
      
      try {
        await authService.signOut();
        await _auth.signOut();
        showDeletedMessage();
      } catch (e) {
        print('Error during signout: $e');
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/welcome', 
          (route) => false
        );
      });
      
      return false;
    } finally {
      setState(() {
        deleting = false;
      });
    }
  }

  Widget _buildDeletionOverlay() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (!deleting) return const SizedBox.shrink();
    
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Deleting Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'This may take a moment. Please wait while we delete your account and all associated data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Column(
      children: [
        if (_isCropping) ...[
          const SizedBox(height: 20),
          Text(
            'Crop Your Profile Picture',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 10),
          Text(
            'Adjust the square to frame your photo',
            style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
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
                      baseColor: theme.colorScheme.primary,
                      maskColor: themeProvider.isDarkMode ? Colors.white.withAlpha(100) : Colors.black.withAlpha(100),
                      cornerDotBuilder: (size, edgeAlignment) => DotControl(color: theme.colorScheme.primary),
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
                const SizedBox(width: 20),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cropImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Crop Image'),
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
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: _currentProfileImageUrl == null || _currentProfileImageUrl!.isEmpty
                        ? Icon(Icons.person, size: 40, color: theme.colorScheme.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
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
          Text(
            'Tap to change profile picture',
            style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 30),
        ],
      ],
    );
  }

  void _showLogoutConfirmation(AuthService authService, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('LOGGING OUT', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
        content: const Text('Are you sure you want to log out of your account?', style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authService.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/welcome', 
                (route) => false
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggleSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'APPEARANCE',
          style: TextStyle(
            fontSize: 16,
            color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        themeProvider.isDarkMode 
                          ? 'Switch to light appearance'
                          : 'Switch to dark appearance',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme(value);
                },
                activeColor: theme.colorScheme.primary,
                activeTrackColor: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackForumSection(ThemeProvider themeProvider) {
    // final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text(
          'FEATURE REQUESTS',
          style: TextStyle(
            fontSize: 16,
            color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: themeProvider.isDarkMode ? Colors.blue.shade800 : Colors.blue.shade100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: themeProvider.isDarkMode ? Colors.blue.shade300 : Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Feature Requests Forum',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Browse, upvote, and track feature requests from other users. See what\'s being planned and vote for your favorite ideas!',
                style: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    _dismissKeyboard();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeedbackForumScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'VIEW FEATURE REQUESTS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: themeProvider.getBackgroundColor(context),
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Adjust Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555),
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: theme.colorScheme.primary),
          backgroundColor: themeProvider.getSurfaceColor(context),
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            _isCropping 
              ? _buildProfilePictureSection()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfilePictureSection(),
                      
                      // Theme Toggle Section
                      _buildThemeToggleSection(),
                      const SizedBox(height: 30),
                      
                      // Feature Requests Forum Section
                      
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SUBSCRIPTION',
                              style: TextStyle(
                                fontSize: 16,
                                color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              'You are on an exclusive access subscription.',
                              style: TextStyle(fontSize: 16, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
                            ),
                            const SizedBox(height: 30),
                            
                            Text(
                              'GENERAL',
                              style: TextStyle(
                                fontSize: 16,
                                color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            Text(
                              'Username',
                              style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              focusNode: _usernameFocusNode,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.red, width: 1),
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.red, width: 2),
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
                            
                            Text(
                              'Email',
                              style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              enabled: false,
                              style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
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
                            
                            if (_isEmailPasswordUser) ...[
                              const SizedBox(height: 40),
                              Text(
                                'CHANGE PASSWORD',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 25),
                              
                              Text(
                                'Current Password',
                                style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _oldPasswordController,
                                focusNode: _oldPasswordFocusNode,
                                obscureText: true,
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () {
                                  FocusScope.of(context).requestFocus(_newPasswordFocusNode);
                                },
                                style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: 'Enter your current password',
                                  hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff555555)),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.red, width: 1),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.red, width: 2),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
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
                              
                              Text(
                                'New Password',
                                style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _newPasswordController,
                                focusNode: _newPasswordFocusNode,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onEditingComplete: _dismissKeyboard,
                                style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: 'Enter your new password',
                                  hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff555555)),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.red, width: 1),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.red, width: 2),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                ),
                                validator: (value) {
                                  if (value != null && value.isNotEmpty && value.length < 6) {
                                    return 'Password must be at least 6 characters long';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            // // Weekly Digest Section
                            // const SizedBox(height: 30),
                            // Text(
                            //   'NOTIFICATIONS',
                            //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e)),
                            // ),
                            // const SizedBox(height: 15),
                            // Row(
                            //   crossAxisAlignment: CrossAxisAlignment.start,
                            //   children: [
                            //     Expanded(
                            //       child: Column(
                            //         crossAxisAlignment: CrossAxisAlignment.start,
                            //         children: [
                            //           Text(
                            //             'Weekly Digest',
                            //             style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
                            //           ),
                            //           Text(
                            //             'Receive weekly summary of relationships needing attention',
                            //             style: TextStyle(fontSize: 14, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                            //           ),
                            //         ],
                            //       ),
                            //     ),
                            //     Container(
                            //       width: 100,
                            //       child: Switch(
                            //         value: _weeklyDigestEnabled,
                            //         inactiveThumbColor: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.white,
                            //         inactiveTrackColor: themeProvider.isDarkMode ? Colors.grey.shade700 : const Color(0xffdddddd),
                            //         onChanged: (value) {
                            //           setState(() {
                            //             _weeklyDigestEnabled = value;
                            //           });
                            //           _updateWeeklyDigestSetting(value);
                            //         },
                            //         activeColor: theme.colorScheme.primary,
                            //       ),
                            //     )
                            //   ],
                            // ),
                            
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: _isChangingPassword
                                  ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                                  : ElevatedButton(
                                      onPressed: () {
                                        _dismissKeyboard();
                                        _updateUserData();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text(
                                        'CONFIRM CHANGES',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ?Colors.black:Colors.white),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Delete Account Section
                      const SizedBox(height: 40),
                      Text(
                        'ACCOUNT ACTIONS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e)),
                      ),
                      const SizedBox(height: 35),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            _dismissKeyboard();
                            _showLogoutConfirmation(authService, themeProvider);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(color: theme.colorScheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'LOG OUT',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 35),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            _dismissKeyboard();
                            _showDeleteAccountConfirmation(authService, themeProvider);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'DELETE ACCOUNT',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Feedback Section
                        _buildFeedbackForumSection(themeProvider),
                      
                      const SizedBox(height: 30),

                      _buildFeedbackForm(themeProvider),
                      
                      const SizedBox(height: 30),
                      
                      // Feedback Management Section (for admins)
                      _currentUser!.admin
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 16, bottom: 16, left: 16, right: 16),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FEEDBACK MANAGEMENT',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff6e6e6e)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'View and manage user feedback submissions',
                                style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _dismissKeyboard();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const FeedbackManagementScreen(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'MANAGE FEEDBACK',
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
                        )
                      : const SizedBox(),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
            _buildDeletionOverlay(),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _feedbackMessageFocusNode.dispose();
    _usernameFocusNode.dispose();
    _oldPasswordFocusNode.dispose();
    _newPasswordFocusNode.dispose();

    _usernameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _feedbackTypeController.dispose();
    _feedbackMessageController.dispose();
    super.dispose();
  }
}