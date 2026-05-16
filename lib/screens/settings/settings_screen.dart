// settings_screen.dart - Updated with theme toggle and Feedback Forum link
import 'dart:io';
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nudge/helpers/deletion_retry_helper.dart';
import 'package:nudge/providers/admin_provider.dart';
import 'package:nudge/providers/subscription_provider.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/screens/admin/feedback_management_screen.dart';
import 'package:nudge/screens/admin/ai_testing_screen.dart';
import 'package:nudge/screens/feedback/feedback_bottom_sheet.dart';
import 'package:nudge/screens/feedback/feedback_forum_screen.dart';
import 'package:nudge/screens/subscription/paywall_screen.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/widgets/screen_tracker.dart';
import 'package:nudge/widgets/stitch_top_bar.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:nudge/models/user.dart' as user;


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
  // user.User? _currentUser;
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
        // _currentUser = userData;
        _currentProfileImageUrl = userData.photoUrl;
        // _weeklyDigestEnabled = userData.weeklyDigestEnabled;
        _isLoading = false;
      });
    } catch (e) {
      //print('Error loading user data: $e');
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
        backgroundColor: AppColors.success,
        icon: Icons.check,
      );
    } catch (e) {
      TopMessageService().showMessage(
          context: context,
          message: 'Failed to update profile picture.',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
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
          backgroundColor: AppColors.success,
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
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          icon: Icons.error,
        );
      } catch (e) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error updating profile: $e')),
        // );
        TopMessageService().showMessage(
          context: context,
          message: 'Error updating profile: $e',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
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
          backgroundColor: AppColors.success,
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
          backgroundColor: Theme.of(context).colorScheme.tertiary,
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 15),
          
          Text('Type', style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              _dismissKeyboard();
              _showFeedbackTypeDialog(themeProvider);
            },
            child: AbsorbPointer(
              child: TextFormField(
                controller: _feedbackTypeController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                    borderRadius: BorderRadius.circular(14)
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(14)
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
          
          Text('Comments', style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _feedbackMessageController,
            focusNode: _feedbackMessageFocusNode,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onEditingComplete: () {
              _dismissKeyboard();
            },
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Please share your feedback, suggestions, or issues...',
              hintStyle: TextStyle(color: themeProvider.isDarkMode? Color(0xff666666):Color(0xff999999), fontFamily: 'Inter'),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Center(
                      child: Text(
                      'SUBMIT FEEDBACK',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
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
          title: Text('SELECT FEEDBACK TYPE', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _feedbackTypes.length,
              itemBuilder: (context, index) {
                final type = _feedbackTypes[index];
                return ListTile(
                  title: Text(type, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
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
  //     //print('Error updating weekly digest setting: $e');
  //   }
  // }

  void _showDeleteAccountConfirmation(AuthService authService, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('DELETE ACCOUNT', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        content: const Text(
          'This action cannot be undone. All your data, contacts, groups, and settings will be permanently deleted.',
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
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
              foregroundColor: deleting ? Theme.of(context).colorScheme.outline : Color.fromARGB(255, 206, 37, 85),
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
    //               Text(
    //                 'Deleted Account!',
    //                 style: TextStyle(
    //                   fontWeight: FontWeight.bold,
    //                   color: Theme.of(context).colorScheme.onSurface,
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
    //     backgroundColor: AppColors.success,
    //     duration: const Duration(seconds: 4),
    //   ),
    // );

    TopMessageService().showCustomContent(
      context: context,
      backgroundColor: AppColors.success,
      height: 150,
      customContent: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Deleted Account!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
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
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Try Again'),
        content: const Text(
          'Please try deleting your account again. The app state has been refreshed.',
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
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
          backgroundColor: Theme.of(context).colorScheme.tertiary,
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
      //print('Error deleting user: $error');
      
      try {
        await authService.signOut();
        await _auth.signOut();
        showDeletedMessage();
      } catch (e) {
        //print('Error during signout: $e');
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

  // ── Subscription card (purple gradient) ─────────────────────────────────
  Widget _buildSubscriptionCard() {
    final sub = context.watch<SubscriptionProvider>();
    final planLabel = sub.isTrial
        ? 'PRO TRIAL'
        : '${sub.subscription.tierName.toUpperCase()} PLAN';
    final description = sub.isTrial
        ? 'Your free 14-day Pro trial is active.'
        : sub.isFree
            ? 'Upgrade to unlock more contacts & features.'
            : 'You\'re on the ${sub.subscription.tierName} plan — ${sub.subscription.tierTagline}.';
    final buttonLabel = sub.isFree || sub.isTrial ? 'Upgrade Plan' : 'Manage Plan';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF751FE7), Color(0xFF4A0FAA)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF751FE7).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(children: [
        Positioned(
          top: -12, right: 20,
          child: Transform.rotate(
            angle: 0.4,
            child: Icon(Icons.star_rounded,
                size: 72, color: Colors.white.withOpacity(0.10)),
          ),
        ),
        Positioned(
          top: 24, right: -8,
          child: Transform.rotate(
            angle: -0.3,
            child: Icon(Icons.star_rounded,
                size: 44, color: Colors.white.withOpacity(0.07)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                planLabel,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Subscription',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.8), height: 1.4),
            ),
            if (sub.isTrial && sub.subscription.periodEnd != null) ...[
              const SizedBox(height: 4),
              Text(
                '${sub.subscription.periodEnd!.difference(DateTime.now()).inDays} days remaining',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.65),
                    fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF751FE7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999)),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Color(0xFF751FE7)),
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  // ── Privacy Policy card ───────────────────────────────────────────────────
  Widget _buildPrivacyPolicyCard(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
    final textP  = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final textS  = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;
    const brandPurple = Color(0xFF751FE7);

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(
            'https://www.freeprivacypolicy.com/live/25cee199-538c-4c40-8fae-dbc5f4a128a0');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: brandPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.privacy_tip_outlined,
                size: 18, color: brandPurple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textP,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'How we collect and use your data',
                  style: TextStyle(
                    fontSize: 12,
                    color: textS,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded, color: textS, size: 18),
        ]),
      ),
    );
  }

  // ── Log Out card ─────────────────────────────────────────────────────────
  Widget _buildLogOutCard(AuthService authService, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
    final textP  = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;

    return GestureDetector(
      onTap: () {
        _dismissKeyboard();
        _showLogoutConfirmation(authService, themeProvider);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
              blurRadius: 10, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerHighest
                  : const Color(0xFFF0EDE9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.logout_rounded,
                size: 18, color: textP),
          ),
          const SizedBox(width: 14),
          Text(
            'Log Out',
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: textP),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.lightOnSurfaceVariant,
              size: 20),
        ]),
      ),
    );
  }

  // ── Danger Zone card ─────────────────────────────────────────────────────
  Widget _buildDangerZoneCard(AuthService authService, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final errorColor = Color.fromARGB(255, 206, 37, 85);

    // Subtle tinted background — not pure red, just a warm blush
    final cardBg = isDark
        ? const Color(0xFF2A1010)   // very dark red-tinted surface
        : const Color(0xFFFFF0F0);  // very light blush

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: errorColor.withOpacity(isDark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger Zone',
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: errorColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Permanently delete your account and all associated nudges. '
            'This action cannot be undone.',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Inter',
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.lightOnSurfaceVariant,
              height: 1.5),
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: () {
              _dismissKeyboard();
              _showDeleteAccountConfirmation(authService, themeProvider);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: errorColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    size: 16, color: errorColor),
              ),
              const SizedBox(width: 10),
              Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: errorColor),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletionOverlay() {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (!deleting) return const SizedBox.shrink();
    
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 206, 37, 85)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Deleting Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 206, 37, 85),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'This may take a moment. Please wait while we delete your account and all associated data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          Text(
            'Adjust the square to frame your photo',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                      foregroundColor: Color.fromARGB(255, 206, 37, 85),
                      side: BorderSide(color: Color.fromARGB(255, 206, 37, 85)),
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
                      child: Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.onInverseSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to change profile picture',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
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
        title: Text('LOGGING OUT', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        content: const Text('Are you sure you want to log out of your account?', style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Clear cached subscription on sign-out
              if (context.mounted) {
                await Provider.of<SubscriptionProvider>(context, listen: false)
                    .clearSubscription();
              }
              await authService.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/welcome',
                (route) => false
              );
            },
            style: TextButton.styleFrom(foregroundColor: Color.fromARGB(255, 206, 37, 85)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggleSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    // final scheme = Theme.of(context).colorScheme;

    final cardBg   = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
    final textP    = isDark ? AppColors.darkOnSurface             : AppColors.lightOnSurface;
    final textS    = isDark ? AppColors.darkOnSurfaceVariant      : AppColors.lightOnSurfaceVariant;
    final fieldBg  = isDark ? AppColors.darkSurfaceContainerHighest : const Color(0xFFF0EDE9);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: palette icon + title
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.palette_outlined,
                  color: AppColors.lightPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: textP),
            ),
          ]),
          const SizedBox(height: 12),

          // Description
          Text(
            'Choose how Nudge looks on your device. Auto syncs with your system settings.',
            style: TextStyle(fontSize: 13, color: textS, height: 1.5),
          ),
          const SizedBox(height: 18),

          // Light / Dark pill toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(children: [
              // Light pill
              Expanded(
                child: GestureDetector(
                  onTap: () => themeProvider.toggleTheme(false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 40,
                    decoration: BoxDecoration(
                      color: !isDark ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: !isDark
                          ? [BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8, offset: const Offset(0, 1))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.light_mode_rounded,
                          size: 16,
                          color: !isDark ? AppColors.lightPrimary : textS),
                        const SizedBox(width: 6),
                        Text('Light',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: !isDark ? AppColors.lightPrimary : textS)),
                      ],
                    ),
                  ),
                ),
              ),
              // Dark pill
              Expanded(
                child: GestureDetector(
                  onTap: () => themeProvider.toggleTheme(true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dark_mode_rounded,
                          size: 16,
                          color: isDark ? AppColors.darkPrimary : textS),
                        const SizedBox(width: 6),
                        Text('Dark',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkPrimary : textS)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // Single-row settings tile (white card, icon + label + chevron) matching
  // the mockup's "Submit Feedback / View Feedback Forum / Log Out" pattern.
  Widget _buildSettingsRow({
    required ThemeProvider themeProvider,
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconBg,
    Color? iconFg,
    required VoidCallback onTap,
  }) {
    final isDark = themeProvider.isDarkMode;
    final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
    final textP = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final textS = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;
    const brandPurple = Color(0xFF751FE7);
    return GestureDetector(
      onTap: () {
        _dismissKeyboard();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg ?? brandPurple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconFg ?? brandPurple),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textP)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: textS)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textS, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackForumSection(ThemeProvider themeProvider) {
    return _buildSettingsRow(
      themeProvider: themeProvider,
      icon: Icons.forum_outlined,
      title: 'View Feedback Forum',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FeedbackForumScreen()),
      ),
    );
  }

  Widget _buildSubmitFeedbackRow(ThemeProvider themeProvider) {
    return _buildSettingsRow(
      themeProvider: themeProvider,
      icon: Icons.send_rounded,
      title: 'Submit Feedback',
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FeedbackBottomSheet(currentSection: 'settings'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminProvider = Provider.of<AdminProvider>(context);
    final theme = Theme.of(context);
    
    if (_isLoading /* || adminProvider.isLoading */) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            _isCropping
              ? _buildProfilePictureSection()
              : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StitchTopBar(
                        showBack: true,
                        avatarUrl: authService.currentUser?.photoURL,
                      ),
                      const StitchScreenTitle(
                        title: 'Settings',
                        subtitle: 'Manage your account and app preferences.',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildProfilePictureSection(),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildThemeToggleSection(),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSubscriptionCard(),
                            const SizedBox(height: 24),

                            Text(
                              'GENERAL',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            Text(
                              'Username',
                              style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              focusNode: _usernameFocusNode,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Username',
                                hintStyle: TextStyle(color: themeProvider.isDarkMode? Color(0xff666666):Color(0xff999999)),
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
                              style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              enabled: false,
                             style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                                  borderRadius: BorderRadius.circular(14)
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
                                  color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : AppColors.lightOnSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 25),
                              
                              Text(
                                'Current Password',
                                style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
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
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Enter your current password',
                                  hintStyle: TextStyle(color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : AppColors.lightOnSurface),
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
                                style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _newPasswordController,
                                focusNode: _newPasswordFocusNode,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onEditingComplete: _dismissKeyboard,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Enter your new password',
                                  hintStyle: TextStyle(color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : AppColors.lightOnSurface),
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
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Mockup row order: Submit Feedback / View Forum /
                      // Log Out / Danger Zone. Privacy Policy stays just
                      // above as a related external-link row.
                      const SizedBox(height: 30),
                      _buildPrivacyPolicyCard(themeProvider),
                      const SizedBox(height: 12),
                      _buildSubmitFeedbackRow(themeProvider),
                      const SizedBox(height: 12),
                      _buildFeedbackForumSection(themeProvider),
                      const SizedBox(height: 12),
                      _buildLogOutCard(authService, themeProvider),
                      const SizedBox(height: 16),
                      _buildDangerZoneCard(authService, themeProvider),

                      const SizedBox(height: 30),
                      
                      // Feedback Management Section (for admins)
                      adminProvider.isAdmin
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 16, bottom: 16, left: 16, right: 16),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FEEDBACK MANAGEMENT',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.inverseSurface : AppColors.lightOnSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'View and manage user feedback submissions',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                                    backgroundColor: Theme.of(context).colorScheme.secondary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    'MANAGE FEEDBACK',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onInverseSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(),

                      // ── AI Integration Testing (admin only) ───────────
                      if (adminProvider.isAdmin) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.lightPrimary.withOpacity(
                                    themeProvider.isDarkMode ? 0.20 : 0.08),
                                AppColors.lightSecondary.withOpacity(
                                    themeProvider.isDarkMode ? 0.14 : 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.lightPrimary.withOpacity(
                                  themeProvider.isDarkMode ? 0.30 : 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.lightPrimary,
                                    borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.auto_awesome_rounded,
                                      size: 14, color: Colors.white)),
                                const SizedBox(width: 10),
                                Text(
                                  'AI INTEGRATION',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: themeProvider.isDarkMode
                                        ? AppColors.darkOnSurface
                                        : AppColors.lightOnSurface),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                'Test Claude AI features — nudge copy, greeting cards, weekly digest and the relationship assistant.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _dismissKeyboard();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AITestingScreen()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.lightPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: const Text(
                                    'OPEN AI TESTING PANEL',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                        ],
                        ),
                      ),
                    ],
                  ),
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