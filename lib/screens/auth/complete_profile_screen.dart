// complete_profile_screen.dart - Enhanced with Social Universe Preview
import 'dart:typed_data';

// import 'package:another_flushbar/flushbar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
// import 'package:nudge/main.dart';
// import 'package:nudge/main.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/add_contact_screen.dart';
import 'package:nudge/services/message_service.dart';
// import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:nudge/helpers/restart_helper.dart';
import 'package:nudge/widgets/roadmap_widget.dart';
// import 'package:nudge/widgets/roadmap_widget.dart';
// import 'package:nudge/widgets/scrollable_roadmap.dart';
import 'package:nudge/widgets/social_universe_guide.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
// import '../contacts/import_contacts_screen.dart';

// Add these imports for contact picking functionality
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;
import '../../services/contact_sync_service.dart';
import '../../providers/theme_provider.dart';

// Import the Social Universe widget
// import 'package:nudge/widgets/social_universe.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final _imageDataList = <Uint8List>[];
  var _currentImage = 0;
  String? _expandedGroupId;
  set currentImage(int value) {
    setState(() {
      _currentImage = value;
    });
    _cropController.image = _imageDataList[_currentImage];
  }
  
  // Cropping state
  bool _isCropping = false;
  final _cropController = CropController();
  Uint8List? _imageBytes;
  
  // Onboarding state
  int _currentStep = 0;
  List<Contact> _selectedContacts = [];
  Set<String>? _selectedGoals; // null = user hasn't engaged with step yet
  final List<Contact> _closeCircleContacts = [];
  final List<SocialGroup> _userGroups = [];

  // Country code
  CountryCode _selectedCountry = CountryCode(dialCode: '+971', code: 'AE');


  // Steps configuration - Updated with preview step
  final List<Map<String, dynamic>> _steps = [
    {'title': 'Complete Your Profile', 'subtitle': 'Tell us about yourself'},
    {'title': 'Create Social Groups', 'subtitle': 'Organize your contacts'},
    // {'title': 'Welcome to Your Social Universe', 'subtitle': 'See what we\'re building'},
    {'title': 'Add Your Contacts', 'subtitle': 'Import or add contacts'},
    {'title': 'Identify Favourites', 'subtitle': 'Mark important relationships'},
    {'title': 'What Matters Most to You?', 'subtitle': 'Personalize your nudges'},
    // {'title': 'Review Setup', 'subtitle': 'You\'re all set!'},
    {'title': 'What\'s Coming to NUDGE', 'subtitle': 'See our roadmap'}, // New step
  ];

  // Mock contacts for preview
  // final List<Contact> _mockPreviewContacts = [
  //   Contact(
  //     id: 'preview_1',
  //     name: 'Alex Johnson',
  //     phoneNumber: '+1234567890',
  //     email: 'alex@example.com',
  //     priority: 1,
  //     notes: '',
  //     imageUrl: '',
  //     interactionHistory: {},
  //     connectionType: 'Friend',
  //     socialGroups: [],
  //     frequency: 2,
  //     period: 'Weekly',
  //     lastContacted: DateTime.now().subtract(const Duration(days: 3)),
  //     computedRing: 'inner',
  //     rawBand: 'inner',
  //     rawBandSince: DateTime.now().subtract(const Duration(days: 30)),
  //     cdi: 85,
  //     angleDeg: 45,
  //     isVIP: true,
  //     interactionCountInWindow: 12,
  //     tags: ['Close', 'Gym buddy'],
  //   ),
  //   Contact(
  //     id: 'preview_2',
  //     name: 'Sarah Miller',
  //     phoneNumber: '+1234567891',
  //     email: 'sarah@example.com',
  //     priority: 1,
  //     notes: '',
  //     imageUrl: '',
  //     interactionHistory: {},
  //     socialGroups: [],
  //     connectionType: 'Family',
  //     frequency: 1,
  //     period: 'Weekly',
  //     lastContacted: DateTime.now().subtract(const Duration(days: 7)),
  //     computedRing: 'inner',
  //     rawBand: 'inner',
  //     rawBandSince: DateTime.now().subtract(const Duration(days: 90)),
  //     cdi: 90,
  //     angleDeg: 120,
  //     isVIP: false,
  //     interactionCountInWindow: 8,
  //     tags: ['Sister', 'Emergency'],
  //   ),
  //   Contact(
  //     id: 'preview_3',
  //     name: 'Michael Chen',
  //     phoneNumber: '+1234567892',
  //     email: 'michael@example.com',
  //     priority: 1,
  //     notes: '',
  //     imageUrl: '',
  //     socialGroups: [],
  //     interactionHistory: {},connectionType: 'Colleague',
  //     frequency: 2,
  //     period: 'Monthly',
  //     lastContacted: DateTime.now().subtract(const Duration(days: 14)),
  //     computedRing: 'middle',
  //     rawBand: 'middle',
  //     rawBandSince: DateTime.now().subtract(const Duration(days: 60)),
  //     cdi: 65,
  //     angleDeg: 210,
  //     isVIP: false,
  //     interactionCountInWindow: 5,
  //     tags: ['Work', 'Project'],
  //   ),
  //   Contact(
  //     id: 'preview_4',
  //     name: 'David Wilson',
  //     phoneNumber: '+1234567893',
  //     email: 'david@example.com',
  //     priority: 1,
  //     notes: '',
  //     imageUrl: '',
  //     socialGroups: [],
  //     interactionHistory: {},
  //     connectionType: 'Client',
  //     frequency: 1,
  //     period: 'Quarterly',
  //     lastContacted: DateTime.now().subtract(const Duration(days: 45)),
  //     computedRing: 'outer',
  //     rawBand: 'outer',
  //     rawBandSince: DateTime.now().subtract(const Duration(days: 120)),
  //     cdi: 40,
  //     angleDeg: 300,
  //     isVIP: false,
  //     interactionCountInWindow: 2,
  //     tags: ['Business', 'Important'],
  //   ),
  //   Contact(
  //     id: 'preview_5',
  //     name: 'Emma Davis',
  //     phoneNumber: '+1234567894',
  //     email: 'emma@example.com',
  //     priority: 1,
  //     notes: '',
  //     imageUrl: '',
  //     socialGroups: [],
  //     interactionHistory: {},connectionType: 'Friend',
  //     frequency: 1,
  //     period: 'Monthly',
  //     lastContacted: DateTime.now().subtract(const Duration(days: 21)),
  //     computedRing: 'middle',
  //     rawBand: 'middle',
  //     rawBandSince: DateTime.now().subtract(const Duration(days: 75)),
  //     cdi: 55,
  //     angleDeg: 150,
  //     isVIP: false,
  //     interactionCountInWindow: 4,
  //     tags: ['College', 'Travel'],
  //   ),
  //   Contact(
  //     id: 'preview_6',
  //     name: 'Robert Taylor',
  //     phoneNumber: '+1234567895',
  //     email: 'robert@example.com',
  //      priority: 1,
  //     notes: '',
  //     imageUrl: '',
  //     socialGroups: [],
  //     interactionHistory: {},connectionType: 'Mentor',
  //     frequency: 2,
  //     period: 'Annually',
  //     lastContacted: DateTime.now().subtract(const Duration(days: 90)),
  //     computedRing: 'outer',
  //     rawBand: 'outer',
  //     rawBandSince: DateTime.now().subtract(const Duration(days: 180)),
  //     cdi: 35,
  //     angleDeg: 30,
  //     isVIP: true,
  //     interactionCountInWindow: 1,
  //     tags: ['Advisor', 'Expert'],
  //   ),
  //   Contact(
  //     id: 'preview_7',
  //     name: 'Lisa Brown',
  //     phoneNumber: '+1234567896',
  //     email: 'lisa@example.com',
  //     connectionType: 'Family',
  //     priority: 1,
  //     notes: '',
  //     imageUrl: '',
  //     socialGroups: [],
  //     interactionHistory: {},
  //     frequency: 3,
  //     period: 'Weekly',
  //     lastContacted: DateTime.now().subtract(const Duration(days: 1)),
  //     computedRing: 'inner',
  //     rawBand: 'inner',
  //     rawBandSince: DateTime.now().subtract(const Duration(days: 365)),
  //     cdi: 95,
  //     angleDeg: 75,
  //     isVIP: false,
  //     interactionCountInWindow: 15,
  //     tags: ['Mother', 'Close'],
  //   ),
  //   Contact(
  //     id: 'preview_8',
  //     name: 'James Wilson',
  //     phoneNumber: '+1234567897',
  //     email: 'james@example.com',
  //     connectionType: 'Colleague',
  //     priority: 1,
  //     notes: '',
  //     imageUrl: '',
  //     socialGroups: [],
  //     interactionHistory: {},frequency: 1,
  //     period: 'Monthly',
  //     lastContacted: DateTime.now().subtract(const Duration(days: 28)),
  //     computedRing: 'outer',
  //     rawBand: 'outer',
  //     rawBandSince: DateTime.now().subtract(const Duration(days: 150)),
  //     cdi: 30,
  //     angleDeg: 250,
  //     isVIP: false,
  //     interactionCountInWindow: 3,
  //     tags: ['Work', 'Team'],
  //   ),
  // ];

  @override
  void initState() {
    super.initState();
    _initializeDefaultGroups();
    // Start at step 0 (profile) instead of preview
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _initializeDefaultGroups() {
    _userGroups.addAll([
      SocialGroup(
        id: 'family', 
        name: 'Family', 
        frequency: 2,
        period: 'Monthly',
        colorCode: '#4FC3F7', 
        description: '', 
        memberCount: 0, 
        memberIds: [], 
        lastInteraction: DateTime.now(), 
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 0,
      ),
      SocialGroup(
        id: 'friend', 
        name: 'Friend', 
        frequency: 2,
        period: 'Weekly',
        colorCode: '#FF6F61', 
        description: '', 
        memberCount: 0, 
        memberIds: [], 
        lastInteraction: DateTime.now(), 
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 1
      ),
      SocialGroup(
        id: 'colleague', 
        name: 'Colleague', 
        frequency: 2,
        period: 'Monthly',
        colorCode: '#81C784', 
        description: '', 
        memberCount: 0, 
        memberIds: [], 
        lastInteraction: DateTime.now(), 
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 2
      ),
      SocialGroup(
        id: 'client', 
        name: 'Client', 
        frequency: 1,
        period: 'Quarterly',
        colorCode: '#FFC107', 
        description: '', 
        memberCount: 0, 
        memberIds: [], 
        lastInteraction: DateTime.now(), 
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 3
      ),
      SocialGroup(
        id: 'mentor', 
        name: 'Mentor', 
        frequency: 2,
        period: 'Annually',
        colorCode: '#607D8B', 
        description: '', 
        memberCount: 0, 
        memberIds: [], 
        lastInteraction: DateTime.now(), 
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 4
      ),
    ]);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
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
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(_imageBytes!.toList());
    
    setState(() {
      _isCropping = false;
      _imageBytes = null;
    });
  }

  void _cancelCrop() {
    setState(() {
      _isCropping = false;
      _imageBytes = null;
    });
  }

  Future<Directory> getTemporaryDirectory() async {
    return Directory.systemTemp;
  }

  void _nextStep(bool isDarkMode) {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding(isDarkMode);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<String> uploadImageToFirebase(Uint8List imageBytes, String fileName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imagesRef = storageRef.child('uploads/$fileName');

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

  Future<void> _completeOnboarding(bool isDarkMode) async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        // STEP 1: Ensure FCM token is stored
        await authService.storeFCMToken();
        
        // STEP 2: Get fresh user data with FCM token
        final freshUserDoc = await apiService.getUser();
        final freshUserMap = freshUserDoc.toMap();
        if (freshUserMap['fcmToken'] == null || freshUserMap['fcmToken'].isEmpty) {
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await apiService.updateUser({'fcmToken': fcmToken});
          } else {
            throw Exception('FCM token is required for notifications');
          }
        }

        // Upload image if selected
        String imageUrl = '';
        if (_imageBytes != null) {
          String uniqueID = _usernameController.text + (DateTime.now().millisecondsSinceEpoch).toString();
          imageUrl = await uploadImageToFirebase(_imageBytes!, uniqueID);
        }
        
        // Update user profile
        await apiService.updateUser({
          'username': _usernameController.text,
          'phoneNumber': '${_selectedCountry.dialCode}${_phoneController.text}',
          'bio': _bioController.text,
          'photoUrl': imageUrl,
          'profileCompleted': true,
          'onboardingCompleted': true,
          'updatedAt': DateTime.now(),
        });
        
        // Save groups
        await apiService.updateGroups(_userGroups);

        if (_closeCircleContacts.isNotEmpty) {
          await apiService.updateCloseCircleContacts(_closeCircleContacts);
        }

        if (_selectedContacts.isNotEmpty) {
          apiService.scheduleRegularNotifications(_selectedContacts);
        }
        
        // Navigate to dashboard using restart approach
        // _navigateToDashboardWithSuccess();
         _showSocialUniverseGuide(context, isDarkMode);
      }
    } catch (e) {
     
    //   Flushbar(
    //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
    //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
    //   messageText: Center(
    //       child: Text('Error: ${e.toString()}', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
    //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
    // ).show(context);
    TopMessageService().showMessage(
        context: context,
        message: 'Error: ${e.toString()}',
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        icon: Icons.error,
      );
      setState(() => _isLoading = false);
    }
  }

  // In the _CompleteProfileScreenState class, add this method:
    void _showSocialUniverseGuide(BuildContext context, bool isDarkMode) {
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SocialUniverseGuide(
            onClose: () {
              // When user clicks "Got It!" or close button
              Navigator.of(context).pop();
              _navigateToDashboardWithSuccess();
            },
            isDarkMode: isDarkMode,
          ),
        );
      },
    );
  }

  void _navigateToDashboardWithSuccess() {
    final apiService = ApiService();
    TopMessageService().showCustomContent(
      context: context,
      backgroundColor: AppColors.success,
      height: 100,
      customContent: Row(
          children: [
            Icon(Icons.celebration, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Onboarding Complete!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Orbitron',
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _selectedContacts.isNotEmpty 
                        ? 'Your first nudges have been scheduled'
                        : 'You can add contacts and schedule nudges anytime',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Orbitron'),
                  ),
                ],
              ),
            ),
          ],
        ));

    Future.delayed(const Duration(milliseconds: 1500), () {
      AppRestartHelper.setSkipSplashFlag();
      AppRestartHelper.forceAppRestart(context);
      apiService.batchUpdateCDI();
    });
  }

  void _toggleCloseCircleContact(Contact contact) {
    setState(() {
      if (_closeCircleContacts.contains(contact)) {
        _closeCircleContacts.remove(contact);
      } else {
        _closeCircleContacts.add(contact);
      }
    });
  }

  Future<void> _pickContactsManually() async {
    FocusScope.of(context).unfocus();
    
    final permissionOk = await fContacts.FlutterContacts.requestPermission();
    if (!permissionOk) {
      _showSettingsDialog('Contacts permission is required to pick contacts');
      return;
    }

    final contacts = await fContacts.FlutterContacts.getContacts(withProperties: true);

    // //print('existing contacts are'); //print(_selectedContacts[0].name);
    final selectedContacts = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactPickerDialog(contacts: contacts, existingContacts: _selectedContacts,),
      ),
    );

    if (selectedContacts == null || selectedContacts.isEmpty) return;

    final SocialGroup? selectedGroup = await showDialog<SocialGroup>(
      context: context,
      builder: (context) => GroupSelectionDialog(groups: _userGroups),
    );

    if (selectedGroup == null) return;

    await _importContactsWithGroup(selectedContacts, selectedGroup);
  }

  void _showSettingsDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeProvider themeProvider) {
    return Container(
      width: double.infinity, // Make container full width
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      child: Column(
        children: [
          // Staggered (broken) lines indicator - full width with horizontal padding
          Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 16), // Add horizontal margin
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space evenly
              children: List.generate(_steps.length, (index) {
                // Only show lines up to current step
                bool isActive = index <= _currentStep;
                
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 4, // Add gap between segments
                      right: index == _steps.length - 1 ? 0 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive 
                          ? AppColors.lightPrimary 
                          : (themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Theme.of(context).colorScheme.surfaceContainerHigh),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Step text - also with horizontal padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step ${_currentStep + 1} of ${_steps.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightPrimary,
                  ),
                ),
                Text(
                  _steps[_currentStep]['title'],
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w500, 
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
    
  Widget _buildCurrentStep() {
    if (_isCropping) {
      return _buildCropScreen();
    }
    
    switch (_currentStep) {
      case 0: return _buildProfileStep();
      // case 1: return _buildPreviewStep();
      case 1: return _buildGroupsStep();
      case 2: return _buildContactsStep();
      case 3: return _buildCloseCircleStep();
      case 4: return _buildWhatMattersStep();
      // case 5: return _buildReviewStep();
      case 5: return _buildRoadmapStep();
      default: return _buildProfileStep();
    }
  }

  // NEW: Preview Step with Social Universe
  // Widget _buildPreviewStep() {
  //   final themeProvider = Provider.of<ThemeProvider>(context);
  //   // final theme = Theme.of(context);
    
  //   return Expanded(
  //     child: ListView(
  //       padding: EdgeInsets.zero,
  //       // crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // Hero section
  //         Container(
  //           padding: const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 40),
  //           child: Column(
  //             children: [
  //               Text(
  //                 'Welcome to',
  //                 style: TextStyle(
  //                   fontSize: 32,
  //                   fontWeight: FontWeight.w700,
  //                   color: Color.fromARGB(255, 15, 57, 142), // Navy blue color
  //                 ),
  //               ),
  //               Text(
  //                 'Your Social Universe',
  //                 style: TextStyle(
  //                   fontSize: 32,
  //                   fontWeight: FontWeight.w700,
  //                   color: Color.fromARGB(255, 15, 57, 142), // Navy blue color
  //                 ),
  //               ),
  //               const SizedBox(height: 16),
  //               Text(
  //                 'Visualize your connections like never before',
  //                 textAlign: TextAlign.center,
  //                 style: TextStyle(
  //                   fontSize: 18,
  //                   color: themeProvider.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.outline,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
          
  //         // Social Universe Preview
  //         Container(
  //           margin: const EdgeInsets.symmetric(horizontal: 16),
  //           child: Card(
  //             elevation: 8,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(20),
  //             ),
  //             child: ClipRRect(
  //               borderRadius: BorderRadius.circular(20),
  //               child: Container(
  //                 height: 350,
  //                 color: themeProvider.isDarkMode ? Colors.black : const Color(0xFF0A1A3B),
  //                 child: SocialUniverseWidget(
  //                   contacts: _mockPreviewContacts,
  //                   showTitle: false,
  //                   onContactView: (contact, ringToUse) {
  //                     // Preview interaction
  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       SnackBar(
  //                         content: Text('In your actual Social Universe, you can view details for ${contact.name}'),
  //                         duration: const Duration(seconds: 2),
  //                       ),
  //                     );
  //                   },
  //                   height: 350,
  //                   isImmersive: false,
  //                   isDarkMode: themeProvider.isDarkMode,
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ),
          
  //         const SizedBox(height: 24),
          
  //         // Features list
  //         Padding(
  //           padding: const EdgeInsets.symmetric(horizontal: 24),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               _buildFeatureItem(
  //                 Icons.star,
  //                 'Visualize Connections',
  //                 'See your relationships in beautiful rings',
  //                 themeProvider,
  //               ),
  //               const SizedBox(height: 16),
  //               _buildFeatureItem(
  //                 Icons.notifications,
  //                 'Smart Reminders',
  //                 'Never lose touch with important people',
  //                 themeProvider,
  //               ),
  //               const SizedBox(height: 16),
  //               _buildFeatureItem(
  //                 Icons.group,
  //                 'Organize Groups',
  //                 'Categorize contacts by relationship type',
  //                 themeProvider,
  //               ),
  //             ],
  //           ),
  //         ),
          
  //         const SizedBox(height: 40),
          
  //         // Call to action
  //         Padding(
  //           padding: const EdgeInsets.symmetric(horizontal: 24),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               // Text(
  //               //   'Customize your social universe in a few easy steps',
  //               //   style: TextStyle(
  //               //     fontSize: 20,
  //               //     fontWeight: FontWeight.w700,
  //               //     color: Theme.of(context).colorScheme.onSurface,
  //               //   ),
  //               // ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 'Let\'s build a Social Universe customized to you',
  //                 style: TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.w700,
  //                   color: themeProvider.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.outline,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
          
  //         const SizedBox(height: 40),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildFeatureItem(IconData icon, String title, String description, ThemeProvider themeProvider) {
  //   return Row(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Container(
  //         width: 40,
  //         height: 40,
  //         decoration: BoxDecoration(
  //           color: AppColors.lightPrimary.withOpacity(0.1),
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         child: Icon(
  //           icon,
  //           color: AppColors.lightPrimary,
  //         ),
  //       ),
  //       const SizedBox(width: 16),
  //       Expanded(
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               title,
  //               style: TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.w600,
  //                 color: Theme.of(context).colorScheme.onSurface,
  //               ),
  //             ),
  //             const SizedBox(height: 4),
  //             Text(
  //               description,
  //               style: TextStyle(
  //                 fontSize: 14,
  //                 color: themeProvider.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.surfaceContainerLow,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Future<void> _importContactsWithGroup(List<fContacts.Contact> deviceContacts, SocialGroup group) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    final syncService = ContactSyncService(apiService: apiService);

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await syncService.importContactsWithGroup(
        pickedContacts: deviceContacts,
        groupId: group.name,
        onProgress: (processed, total) {},
      );

      //print('imported contact length is'); //print(deviceContacts.length);
      //print(deviceContacts[0].name);
      //print('result is'); //print(result);

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final updatedContacts = await apiService.getAllContacts();
        setState(() {
          _selectedContacts = updatedContacts;
        });

    //     Flushbar(
    //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
    //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
    //   messageText: Center(
    //       child: Text('Successfully imported contacts to ${group.name}!}', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
    //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
    // ).show(context);

      TopMessageService().showMessage(
        context: context,
        message: 'Successfully imported contacts to ${group.name}!',
        backgroundColor: AppColors.success,
        icon: Icons.check,
      );
      } else {
    //     Flushbar(
    //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
    //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
    //   messageText: Center(
    //       child: Text('Failed to import contacts: ${result['message']}', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
    //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
    // ).show(context);
      TopMessageService().showMessage(
        context: context,
        message: 'Failed to import contacts: ${result['message']}',
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        icon: Icons.error,
      );
      }
    } catch (e) {
      setState(() => _isLoading = false);
    //   Flushbar(
    //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
    //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
    //   messageText: Center(
    //       child: Text('Error importing contacts: $e}', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
    //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
    // ).show(context);
     TopMessageService().showMessage(
        context: context,
        message: 'Error importing contacts: $e}',
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        icon: Icons.error,
      );
    }
  }

  onUserNameChange(String username) {
    setState(() {
      _usernameController.text = username;
    });
  }

  onPhoneChange(String phone) {
    setState(() {
      _phoneController.text = phone;
    });
  }

  onBioChange(String bio) {
    setState(() {
      _bioController.text = bio;
    });
  }

  Widget _buildCropScreen() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Column(
      children: [
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
                          _imageBytes = croppedImage;
                        case CropFailure(:final cause):
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Error'),
                              content: Text('Failed to crop image: ${cause}'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                      }
                      setState(() => _isCropping = false);
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
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _cropImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Save Crop', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    
    return Column(
      children: [
        _buildStepIndicator(themeProvider),
        Expanded(
      child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // Header with motivational text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                  'Start by telling us about yourself',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                ),
                )
              ],
            ),
            const SizedBox(height: 30),
            
            // Profile Image with Cropping
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: _imageBytes == null 
                          ? Icon(Icons.camera_alt, size: 40, color: theme.colorScheme.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Username
            Text('USERNAME *', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              textCapitalization: TextCapitalization.words,
              onTap: () => _dismissKeyboard(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Enter your username',
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
              validator: (value) => value == null || value.isEmpty ? 'Please enter a username' : null,
              onChanged: onUserNameChange,
            ),
            const SizedBox(height: 20),
            
            // Phone Number with Country Code
            Text('PHONE NUMBER *', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: CountryCodePicker(
                      onChanged: (CountryCode country) {
                        setState(() {
                          _selectedCountry = country;
                        });
                      },
                      initialSelection: _selectedCountry.code,
                      favorite: [_selectedCountry.code!, 'US'],
                      showCountryOnly: false,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      key: Key(_selectedCountry.code!),
                      textStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      searchStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      dialogTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      dialogBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                  )
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 12,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onTap: () => _dismissKeyboard(),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Phone number',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
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
                      errorStyle: const TextStyle(fontSize: 12),
                      fillColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a phone number';
                      } else if (!_isValidPhoneNumber(value)) {
                        return 'Please enter a valid 9-digit phone number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      onPhoneChange(value);
                      if (_formKey.currentState != null) {
                        _formKey.currentState!.validate();
                      }
                    },
                  ),
                ),
              ],
            ),
            _buildPhoneValidationMessage(),
            const SizedBox(height: 20),
            
            // Bio
            Text('BIO', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              onTap: () => _dismissKeyboard(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Tell us a bit about yourself...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant, width: 1),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                fillColor: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                filled: true,
              ),
              onChanged: onBioChange,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ))]);
  }

  Widget _buildGroupsStep() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize your Social Groups',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(left: 20, right: 20),
                child: Text(
                'Create groups to categorize your relationships.\n1. Add, edit or remove groups\n2. Drag to reorder groups by priority',
                style: TextStyle(
                  fontSize: 14,
                  color: themeProvider.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.surfaceContainerLow,
                ),
              ),
              )
            ],
          ),
          const SizedBox(height: 30),
          
          // Add new group button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addNewGroup,
              icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurface, size: 18),
              label: const Text('Add New Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Reorderable list of groups - now with smaller cards
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _userGroups.length,
              itemBuilder: (context, index) {
                final group = _userGroups[index];
                return _buildEditableGroupItem(group, index);
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _userGroups.removeAt(oldIndex);
                  _userGroups.insert(newIndex, item);
                  
                  // Update order indices
                  for (int i = 0; i < _userGroups.length; i++) {
                    _userGroups[i] = _userGroups[i].copyWith(orderIndex: i);
                  }
                });
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  color: Colors.transparent,
                  child: child,
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
    
  Widget _buildEditableGroupItem(SocialGroup group, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final theme = Theme.of(context);
    final isExpanded = _expandedGroupId == group.id;
    
    // Parse color from group.colorCode
    Color groupColor;
    try {
      groupColor = Color(int.parse(group.colorCode.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      groupColor = AppColors.lightPrimary;
    }
    
    return Container(
      key: Key(group.id),
      margin: const EdgeInsets.only(bottom: 6), // Smaller margin
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? Theme.of(context).colorScheme.surfaceContainerHigh 
              : Theme.of(context).colorScheme.surfaceContainerLowest, 
          width: 1
        ),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_expandedGroupId == group.id) {
              _expandedGroupId = null; // Collapse if already expanded
            } else {
              _expandedGroupId = group.id; // Expand this group
            }
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collapsed view - always visible
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // Smaller padding
              child: Row(
                children: [
                  // LEFT SIDE: Circle icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: groupColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getGroupIcon(group.name),
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 15),
                  
                  // MIDDLE: Column with drag widget and group name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag widget at the top of the column
                        ReorderableDragStartListener(
                          index: index,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.drag_handle, 
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Drag to reorder',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Group name below drag widget
                        Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // RIGHT SIDE: Column with delete button and frequency text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    // mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delete button at the top
                      GestureDetector(
                        child: Icon(Icons.delete, color: Color.fromARGB(255, 206, 37, 85), size: 16),
                        onTap: () => _deleteGroup(index),
                        ),
                      const SizedBox(height: 10),
                      // Frequency text below delete button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: groupColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            color: groupColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Expanded view - shows when tapped
            if (isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Column(
                  children: [
                    // const Divider(height: 16),
                    const SizedBox(height: 5),
                    
                    // Group name field
                    TextFormField(
                      initialValue: group.name,
                      onTap: () => _dismissKeyboard(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'GROUP NAME',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode 
                              ? Theme.of(context).colorScheme.surfaceContainerLow 
                              : AppColors.lightOnSurface,
                          fontSize: 13,
                          fontStyle: FontStyle.normal
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: themeProvider.isDarkMode 
                            ? Theme.of(context).colorScheme.surfaceContainerHigh 
                            : Theme.of(context).colorScheme.outline,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _userGroups[index] = group.copyWith(name: value);
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    
                    // Contact Frequency Dropdown
                    DropdownButtonFormField<String>(
                      value: _getCurrentFrequencyChoice(group),
                      onTap: () => _dismissKeyboard(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        labelText: 'CONTACT FREQUENCY',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode 
                              ? Theme.of(context).colorScheme.surfaceContainerLow 
                              : AppColors.lightOnSurface,
                          fontSize: 13,
                          fontStyle: FontStyle.normal
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: themeProvider.isDarkMode 
                            ? Theme.of(context).colorScheme.surfaceContainerHigh 
                            : Theme.of(context).colorScheme.outline,
                      ),
                      items: FrequencyPeriodMapper.frequencyMapping.keys.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value, 
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          final frequencyData = FrequencyPeriodMapper.getFrequencyPeriod(newValue);
                          setState(() {
                            _userGroups[index] = group.copyWith(
                              frequency: frequencyData['frequency'] as int,
                              period: frequencyData['period'] as String,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to get icon for group
  IconData _getGroupIcon(String groupName) {
    if (groupName.toLowerCase().contains('family')) return Icons.family_restroom;
    if (groupName.toLowerCase().contains('friend')) return Icons.people;
    if (groupName.toLowerCase().contains('work') || groupName.toLowerCase().contains('colleague')) return Icons.work;
    if (groupName.toLowerCase().contains('client')) return Icons.business_center;
    if (groupName.toLowerCase().contains('mentor')) return Icons.school;
    return Icons.group;
  }
    
  // Widget _buildColorSelector(int index, SocialGroup group) {
  //     final themeProvider = Provider.of<ThemeProvider>(context);
  //     final List<String> colorOptions = [
  //       '#555555',
  //       '#FF6B6B',
  //       '#4ECDC4',
  //       '#A79826',
  //       '#F9A826',
  //       '#6C5CE7',
  //     ];
      
  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'GROUP COLOR',
  //           style: TextStyle(
  //             color: themeProvider.isDarkMode 
  //                 ? Theme.of(context).colorScheme.surfaceContainerLow 
  //                 : AppColors.lightOnSurface,
  //             fontSize: 14,
  //             fontWeight: FontWeight.w600,
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         Wrap(
  //           spacing: 8,
  //           children: colorOptions.map((color) {
  //             final isSelected = group.colorCode == color;
  //             return GestureDetector(
  //               onTap: () {
  //                 setState(() {
  //                   _userGroups[index] = group.copyWith(colorCode: color);
  //                 });
  //               },
  //               child: Container(
  //                 width: 28, // Reduced from 36
  //                 height: 28, // Reduced from 36
  //                 decoration: BoxDecoration(
  //                   color: Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000),
  //                   shape: BoxShape.circle,
  //                   border: isSelected 
  //                       ? Border.all(
  //                           color: Theme.of(context).colorScheme.onSurface, 
  //                           width: 2
  //                         ) 
  //                       : null,
  //                 ),
  //               ),
  //             );
  //           }).toList(),
  //         ),
  //       ],
  //     );
  //   }

  String _getCurrentFrequencyChoice(SocialGroup group) {
      return FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period);
    }

  bool _isValidPhoneNumber(String phone) {
    String cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanedPhone.length >12 || cleanedPhone.length < 9) {
      return false;
    }
    
    // if (!RegExp(r'^[0-9]{9}$').hasMatch(cleanedPhone)) {
    //   return false;
    // }
    
    return true;
  }

  Widget _buildPhoneValidationMessage() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (_phoneController.text.isEmpty) {
      return const SizedBox.shrink();
    }
    
    if (!_isValidPhoneNumber(_phoneController.text)) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode ? Colors.red.shade900.withOpacity(0.3) : const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.red.shade600, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _phoneController.text.length < 9 
                  ? 'Phone number too short. Must be at least 9 digits.' 
                  : 'Please use only numbers (0-9) for the phone number.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? const Color(0xFF0A3A62) : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightPrimary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Valid phone number: ${_selectedCountry.dialCode} ${_phoneController.text}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.lightPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addNewGroup() {
    _dismissKeyboard();
    setState(() {
      // First, increment orderIndex for all existing groups
      for (int i = 0; i < _userGroups.length; i++) {
        _userGroups[i] = _userGroups[i].copyWith(orderIndex: i + 1);
      }
      
      // Then add the new group at the top with orderIndex 0
      _userGroups.insert(0, SocialGroup(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'New Group',
        description: '',
        period: 'Monthly',
        frequency: 2,
        memberIds: [],
        memberCount: 0,
        lastInteraction: DateTime.now(),
        colorCode: '#2596BE',
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 0 // Set to 0 to appear at the top
      ));
    });
    // Flushbar(
    //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
    //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
    //   messageText: Center(
    //       child: Text('Added a new group at the top!}', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
    //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
    // ).show(context);
     TopMessageService().showMessage(
        context: context,
        message: 'Added a new group at the top!',
        backgroundColor: Colors.blueGrey,
        icon: Icons.info,
      );
  }

  void _deleteGroup(int index) {
    _dismissKeyboard();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text('Delete Group', style: TextStyle(color: Color(0xff777777), fontWeight: FontWeight.w600),),
        content: const Text('Are you sure you want to delete this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _userGroups.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Color.fromARGB(255, 206, 37, 85))),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsStep() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // var size = MediaQuery.of(context).size;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Let\'s Fill Your Social Universe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              // Text(
              //   'Add contacts to start building your universe',
              //   style: TextStyle(
              //     fontSize: 16,
              //     color: themeProvider.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.surfaceContainerLow,
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 30),
          
          Text('ADD YOUR CONTACTS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 10),
          Text('Import your contacts or add them manually. You can skip this and do it later.', 
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          
          contactAddingWidget(themeProvider),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget contactAddingWidget(ThemeProvider themeProvider) {
      // var size = MediaQuery.of(context).size;
      if (Platform.isIOS) {
        // iOS: Single card with two buttons side-by-side
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.person_add_alt_1, size: 50, color: AppColors.lightPrimary),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () async {
                                _dismissKeyboard();
                                final newContact = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddContactScreen(
                                      isOnboarding: true,
                                      groups: _userGroups
                                      ),
                                  ),
                                );
                                
                                if (newContact != null && newContact is Contact) {
                                  setState(() {
                                    _selectedContacts.add(newContact);
                                  });
                                  _showFlushbar();
                                }
                                _showFlushbar();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.lightPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: Text('Add New', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create from scratch',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.contacts, size: 50, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                _dismissKeyboard();
                                _pickContactsManually();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.lightPrimary,
                                side: BorderSide(color: AppColors.lightPrimary),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: const Text('Pick Contacts', style: TextStyle(fontSize: 14)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select from device',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // Android: Quick Import card on top, Add Contacts card below
        return Column(
          children: [
            // Quick Import Card
            // Card(
            //   color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
            //   child: Padding(
            //     padding: const EdgeInsets.all(20),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Text(
            //           'QUICK IMPORT',
            //           style: TextStyle(
            //             fontSize: 18,
            //             fontWeight: FontWeight.bold,
            //             color: Theme.of(context).colorScheme.onSurface,
            //           ),
            //         ),
            //         const SizedBox(height: 8),
            //         Text(
            //           'Import your existing contacts from device',
            //           style: TextStyle(
            //             color: Theme.of(context).colorScheme.onSurfaceVariant,
            //           ),
            //         ),
            //         const SizedBox(height: 20),
            //         ElevatedButton(
            //           onPressed: () async {
            //             _dismissKeyboard();
            //             final result = await Navigator.push(
            //               context,
            //               MaterialPageRoute(
            //                 builder: (context) => ImportContactsScreen(
            //                   groups: _getOrderedGroupsForSelection(),
            //                   isOnboarding: true,
            //                 ),
            //               ),
            //             );
                        
            //             if (result != null && result is List<Contact>) {
            //               final Set<String> existingIds = _selectedContacts.map((c) => c.id).toSet();
            //               final List<Contact> newContacts = result.where((c) => !existingIds.contains(c.id)).toList();
                          
            //               setState(() {
            //                 _selectedContacts.addAll(newContacts);
            //               });
            //               // _showFlushbar();
            //             }
            //             // _showFlushbar();
            //           },
            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: AppColors.lightPrimary,
            //             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            //           ),
            //           child: Text('Import Contacts', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 20),
            // Add Contacts Card (same as iOS but for Android)
            Card(
              color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Icon(Icons.person_add_alt_1, size: 50, color: AppColors.lightPrimary),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  _dismissKeyboard();
                                  final newContact = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddContactScreen(isOnboarding: true),
                                    ),
                                  );
                                  
                                  if (newContact != null && newContact is Contact) {
                                    setState(() {
                                      _selectedContacts.add(newContact);
                                    });
                                    _showFlushbar();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.lightPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                child: Text('Add New', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create from scratch',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              Icon(Icons.contacts, size: 50, color: AppColors.lightPrimary),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () {
                                  _dismissKeyboard();
                                  _pickContactsManually();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.lightPrimary,
                                  side: BorderSide(color: AppColors.lightPrimary),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                child: const Text('Pick Contacts', style: TextStyle(fontSize: 14)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select from device',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    }

      // List<SocialGroup> _getOrderedGroupsForSelection() {
      //   return List.from(_userGroups);
      // }

      Widget _buildCloseCircleStep() {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final theme = Theme.of(context);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Text('Identify Your Favourites', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              ),
              const SizedBox(height: 10),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('What is a Favourite?', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'Your Favourites are people you naturally connect with often and those relationships may not need as much intentionality.',
                      style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              if (_selectedContacts.isNotEmpty) ...[
                Text('Select your Favourites members:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 10),
                
                ..._selectedContacts.map((contact) => Card(
                  color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    title: Text(contact.name, style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                    subtitle: contact.phoneNumber.isNotEmpty ? Text(contact.phoneNumber, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)) : null,
                    secondary: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    ),
                    value: _closeCircleContacts.contains(contact),
                    onChanged: (bool? value) => _toggleCloseCircleContact(contact),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                )).toList(),
              ] else ...[
                Card(
                  color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Icon(Icons.people_outline, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('No Contacts Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      Text('You haven\'t added any contacts yet. You can add them later from the dashboard.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        );
      }

      _showFlushbar() {
        //  Flushbar(
        //     padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
        //     flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
        //     forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
        //     backgroundColor: AppColors.success,
        //     messageText: Center(
        //         child: Text('Successfully Created Contact', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
        //             color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
        //   ).show(context);
         TopMessageService().showMessage(
          context: context,
          message: 'Successfully Created Contact.',
          backgroundColor: AppColors.success,
          icon: Icons.check,
        );
      }

      // Widget _buildReviewStep() {
      //   final themeProvider = Provider.of<ThemeProvider>(context);
      //   final theme = Theme.of(context);
        
      //   return SingleChildScrollView(
      //     padding: const EdgeInsets.symmetric(horizontal: 16),
      //     child: Column(
      //       crossAxisAlignment: CrossAxisAlignment.start,
      //       children: [
      //         const SizedBox(height: 40),
      //         Container(
      //           width: double.infinity,
      //           padding: const EdgeInsets.all(20),
      //           child: Column(children: [
      //             Container(
      //               width: 100, height: 100,
      //               decoration: BoxDecoration(
      //                 color: theme.colorScheme.primary.withOpacity(0.1),
      //                 shape: BoxShape.circle,
      //               ),
      //               child: Icon(Icons.check, size: 50, color: theme.colorScheme.primary),
      //             ),
      //             const SizedBox(height: 20),
      //             Text('Your Social Universe is Ready! 🎉', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface), textAlign: TextAlign.center,),
      //             const SizedBox(height: 16),
      //             Text(
      //               'We\'ve created your groups and scheduled your first nudges. You\'ll start seeing reminders soon — and get your first Weekly Digest this Sunday!',
      //               textAlign: TextAlign.center,
      //               style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
      //             ),
      //           ]),
      //         ),
              
      //         const SizedBox(height: 40),
      //         Text('Your Nudge Setup:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
      //         const SizedBox(height: 20),
              
      //         _buildSummaryItem(Icons.person, 'Profile Complete', 'Username: ${_usernameController.text}'),
      //         _buildSummaryItem(Icons.group, '${_userGroups.length} Social Groups', 'Organized by priority'),
      //         _buildSummaryItem(Icons.contacts, 'Contacts', 'You can add contacts later from the dashboard'),
      //         _buildSummaryItem(Icons.star, 'Favourites', '${_closeCircleContacts.length} important relationships'),
      //         // _buildSummaryItem(Icons.notifications, 'Weekly Digest', 'Starting this Sunday'),
              
      //         const SizedBox(height: 40),
              
      //         // Preview of what's next
      //         Container(
      //           padding: const EdgeInsets.all(16),
      //           decoration: BoxDecoration(
      //             color: theme.colorScheme.primary.withOpacity(0.05),
      //             borderRadius: BorderRadius.circular(16),
      //             border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      //           ),
      //           child: Column(
      //             crossAxisAlignment: CrossAxisAlignment.start,
      //             children: [
      //               Row(
      //                 children: [
      //                   Icon(Icons.star, color: theme.colorScheme.primary),
      //                   const SizedBox(width: 8),
      //                   Text(
      //                     'Explore Your Social Universe',
      //                     style: TextStyle(
      //                       fontWeight: FontWeight.bold,
      //                       color: Theme.of(context).colorScheme.onSurface,
      //                     ),
      //                   ),
      //                 ],
      //               ),
      //               const SizedBox(height: 8),
      //               Text(
      //                 'Visit your dashboard to explore your personalized Social Universe visualization and manage your connections.',
      //                 style: TextStyle(
      //                   color: themeProvider.isDarkMode ? Colors.white70 : Theme.of(context).colorScheme.outline,
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ),
              
      //         const SizedBox(height: 40),
      //       ],
      //     ),
      //   );
      // }

      // ── State for goals step ───────────────────────────────────────────────
      // (declared as instance-level via inline logic — using a Set<String> tracked
      //  in the parent class)

      Widget _buildWhatMattersStep() {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDark = themeProvider.isDarkMode;
        // final scaffoldBg = isDark ? AppColors.darkBackground : const Color(0xFFF2EEE8);
        final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
        final textP = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
        final textS = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

        final goals = [
          "Stay connected with people I'm drifting from",
          "Be more intentional about my relationships",
          "Strengthen my close relationships",
          "Grow and maintain my professional network",
          "Stay close to long-distance family and friends",
          "Reconnect with people from my past",
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Text(
                'What matters most\nto you?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30, fontWeight: FontWeight.w800,
                  color: textP, height: 1.15),
              ),
              const SizedBox(height: 12),
              Text(
                'Select your focus to help us personalize\nyour nudges and reminders.',
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14, color: textS, height: 1.55),
              ),
              const SizedBox(height: 28),

              ...goals.map((goal) {
                final isSelected = (_selectedGoals ?? <String>{}).contains(goal);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGoals ??= {};
                      if (isSelected) {
                        _selectedGoals!.remove(goal);
                      } else {
                        _selectedGoals!.add(goal);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.lightPrimary.withOpacity(
                              isDark ? 0.15 : 0.06)
                          : cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.lightPrimary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                              isDark ? 0.15 : 0.05),
                          blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(goal,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 15, fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? AppColors.darkPrimary
                                      : AppColors.lightPrimary)
                                  : textP,
                              height: 1.3)),
                        ),
                        const SizedBox(width: 12),
                        isSelected
                            ? Container(
                                width: 24, height: 24,
                                decoration: const BoxDecoration(
                                  color: AppColors.lightPrimary,
                                  shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14))
                            : Icon(Icons.chevron_right_rounded,
                                color: textS, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }

      Widget _buildRoadmapStep() {
        // final themeProvider = Provider.of<ThemeProvider>(context);
        
        return Column(
          children: [
            // _buildStepIndicator(themeProvider),
            const RoadmapStepWidget(),
            // const ScrollableRoadmapWidget(),
          ],
        );
      }

      // Widget _buildSummaryItem(IconData icon, String title, String subtitle) {
      //   final themeProvider = Provider.of<ThemeProvider>(context);
      //   final theme = Theme.of(context);
        
      //   return ListTile(
      //     leading: Icon(icon, color: theme.colorScheme.primary),
      //     title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
      //     subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      //   );
      // }

      @override
      Widget build(BuildContext context) {
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
                        fontSize: 25, fontWeight: FontWeight.w800),
                    // Near-black wordmark per Stitch mockups
                    // (no purple/blue gradient anywhere in the app).
                    gradient: LinearGradient(
                      colors: themeProvider.isDarkMode
                          ? const [Color(0xFFE7E1DE), Color(0xFF968DA1)]
                          : const [Color(0xFF1A1A1A), Color(0xFF666666)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  centerTitle: true,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  elevation: 0,
                ),
            body: Column(children: [
              if (_currentStep > 0) _buildStepIndicator(themeProvider),
              Expanded(child: _buildCurrentStep()),
              if (!_isCropping) Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
                  border: Border(
                    top: BorderSide(
                      color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                child: Row(children: [
                  if (_currentStep > 0) Expanded( // Don't show back on preview step
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Back', style: TextStyle(fontSize: _currentStep == _steps.length - 1 ? 14 : 16,),),
                    ),
                  ),
                  if (_currentStep > 0) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    autofocus: true,
                    onPressed: () {
                      //print('trying to continue');
                      _dismissKeyboard();
                      
                      // Handle each step's validation
                      if (_currentStep == 0) {
                        // Profile step - validate form
                        if (_formKey.currentState!.validate()) {
                          _nextStep(themeProvider.isDarkMode);
                        }
                      } else if (_currentStep == 1) {
                        // Groups step - just check if groups exist
                        if (_userGroups.isNotEmpty) {
                          _nextStep(themeProvider.isDarkMode);
                        } else {
                          // Flushbar(
                          //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
                          //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                          //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                          //   messageText: Center(
                          //       child: Text('Please add at least one group!}', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
                          //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
                          // ).show(context);
                           TopMessageService().showMessage(
                              context: context,
                              message: 'Please add at least one group!',
                              backgroundColor: Colors.blueGrey,
                              icon: Icons.info,
                            );
                        }
                      } else {
                        // All other steps (preview, contacts, close circle, review) - just continue
                        _nextStep(themeProvider.isDarkMode);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface))
                        : Text(
                            _currentStep == _steps.length - 1 
                              ? 'Launch Your Universe' 
                              : 'Continue',
                            style: TextStyle(fontSize: _currentStep == _steps.length - 1 ? 14 :16, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode?Colors.black:Colors.white),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
                ]),
              ),
            ]),
          ),
        );
      }

      @override
      void dispose() {
        _usernameController.dispose();
        _phoneController.dispose();
        _bioController.dispose();
        super.dispose();
      }
    }

  class ContactPickerDialog extends StatefulWidget {
    final List<fContacts.Contact> contacts;
    final List<Contact> existingContacts; // Add this parameter

    const ContactPickerDialog({
      super.key, 
      required this.contacts,
      required this.existingContacts, // Require existing contacts
    });

    @override
    State<ContactPickerDialog> createState() => _ContactPickerDialogState();
  }

  class _ContactPickerDialogState extends State<ContactPickerDialog> {
    final List<fContacts.Contact> _selectedContacts = [];
    final TextEditingController _searchController = TextEditingController();
    List<fContacts.Contact> _filteredContacts = [];
    
    // Cache for avatar indices to maintain consistency
    final Map<String, int> _avatarIndexCache = {};

    @override
    void initState() {
      super.initState();
      _filteredContacts = widget.contacts;
    }

    void _dismissKeyboard() {
      FocusScope.of(context).unfocus();
    }

    // Helper method to check if a contact already exists
    bool _isContactAlreadyExists(fContacts.Contact contact) {
      if (widget.existingContacts.isEmpty) return false;
      
      // Check if any phone number matches
      final contactPhones = contact.phones
          .map((phone) => _normalizePhoneNumber(phone.number))
          .where((phone) => phone.isNotEmpty)
          .toList();
      
      if (contactPhones.isEmpty) return false;
      
      for (final existingContact in widget.existingContacts) {
        final existingPhone = _normalizePhoneNumber(existingContact.phoneNumber);
        if (contactPhones.contains(existingPhone)) {
          return true;
        }
      }
      
      return false;
    }

    String _normalizePhoneNumber(String phoneNumber) {
      return phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    }

    // Get cached or new random index for avatar
    int _getAvatarIndex(fContacts.Contact contact) {
      final cacheKey = contact.id;
      
      if (_avatarIndexCache.containsKey(cacheKey)) {
        return _avatarIndexCache[cacheKey]!;
      }
      
      final seed = cacheKey.isEmpty ? 'default' : cacheKey;
      var hash = 0;
      for (var i = 0; i < seed.length; i++) {
        hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
      }
      final index = (hash.abs() % 6) + 1;
      
      _avatarIndexCache[cacheKey] = index;
      return index;
    }

    String _getContactInitials(String name) {
      if (name.isEmpty) return '?';
      
      final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
      
      if (parts.length >= 2) {
        return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
      } else if (parts.length == 1) {
        return parts.first[0].toUpperCase();
      }
      
      return '?';
    }

    void _applyFilter(String query) {
      final q = query.trim().toLowerCase();
      setState(() {
        _filteredContacts = q.isEmpty
            ? widget.contacts
            : widget.contacts.where((c) {
                final name = c.displayName.toLowerCase();
                final phones = c.phones.map((p) => p.number.toLowerCase()).join(' ');
                final emails = c.emails.map((e) => e.address.toLowerCase()).join(' ');
                return name.contains(q) || phones.contains(q) || emails.contains(q);
              }).toList();
      });
    }

    void _selectAll() {
      setState(() {
        _selectedContacts.clear();
        for (final contact in _filteredContacts) {
          if (!_isContactAlreadyExists(contact)) {
            _selectedContacts.add(contact);
          }
        }
      });
    }

    void _clearSelection() {
      setState(() {
        _selectedContacts.clear();
      });
    }

    @override
    Widget build(BuildContext context) {
      final themeProvider = Provider.of<ThemeProvider>(context);
      final isDark = themeProvider.isDarkMode;
      // final scheme = Theme.of(context).colorScheme;

      final scaffoldBg = isDark ? AppColors.darkBackground : const Color(0xFFF2EEE8);
      final cardBg     = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
      final fieldBg    = isDark ? AppColors.darkSurfaceContainerHighest : const Color(0xFFECE7E2);
      final textP      = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
      final textS      = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

      // Build alphabetical sections
      final Map<String, List<fContacts.Contact>> alphaSections = {};
      for (final c in _filteredContacts) {
        final letter = c.displayName.isNotEmpty
            ? c.displayName[0].toUpperCase() : '#';
        alphaSections.putIfAbsent(letter, () => []).add(c);
      }
      final sortedLetters = alphaSections.keys.toList()..sort();

      // Already-in-nudge at top as "frequently contacted"
      final frequent = _filteredContacts
          .where((c) => _isContactAlreadyExists(c))
          .take(3).toList();

      return GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: scaffoldBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: textP, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text('SELECT CONTACTS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: textP, letterSpacing: 0.5)),
            actions: [
              IconButton(
                icon: Icon(Icons.select_all_rounded,
                    color: AppColors.lightPrimary, size: 22),
                tooltip: 'Select all',
                onPressed: _selectAll,
              ),
              IconButton(
                icon: Icon(Icons.deselect_rounded, color: textS, size: 22),
                tooltip: 'Clear selection',
                onPressed: _clearSelection,
              ),
            ],
          ),

          body: Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.beVietnamPro(fontSize: 14, color: textP),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: textS, size: 20),
                    hintText: 'Search by name or number...',
                    hintStyle: GoogleFonts.beVietnamPro(fontSize: 14, color: textS),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: _applyFilter,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Contact list
            Expanded(
              child: _filteredContacts.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 56, color: textS.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('No contacts found',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16, fontWeight: FontWeight.w600,
                            color: textP)),
                      ]))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      children: [
                        // Frequently contacted section
                        if (frequent.isNotEmpty && _searchController.text.isEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                            child: Text('FREQUENTLY CONTACTED',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: textS, letterSpacing: 0.8))),
                          ...frequent.map((c) =>
                              _buildContactCard(c, cardBg, textP, textS, isDark)),
                          const SizedBox(height: 12),
                        ],
                        // Alphabetical sections
                        ...sortedLetters.expand((letter) => [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                            child: Text(letter,
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: textS, letterSpacing: 0.5))),
                          ...alphaSections[letter]!.map((c) =>
                              _buildContactCard(c, cardBg, textP, textS, isDark)),
                        ]),
                      ],
                    ),
            ),
          ]),

          bottomNavigationBar: Container(
            color: scaffoldBg,
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(context).padding.bottom + 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('Cancel',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 16, fontWeight: FontWeight.w500, color: textS)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _selectedContacts.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selectedContacts),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _selectedContacts.isEmpty ? 0.45 : 1.0,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)]),
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: _selectedContacts.isNotEmpty
                          ? [BoxShadow(
                              color: AppColors.lightPrimary.withOpacity(0.4),
                              blurRadius: 16, offset: const Offset(0, 5))]
                          : null,
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text('Import (${_selectedContacts.length})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    // ── Contact card ─────────────────────────────────────────────────────────
    Widget _buildContactCard(
      fContacts.Contact contact,
      Color cardBg, Color textP, Color textS, bool isDark,
    ) {
      final isSelected    = _selectedContacts.contains(contact);
      final alreadyExists = _isContactAlreadyExists(contact);
      final primaryPhone  = contact.phones.isNotEmpty
          ? contact.phones.first.number : '';
      final avatarIndex   = _getAvatarIndex(contact);
      final initials      = contact.displayName.isNotEmpty
          ? _getContactInitials(contact.displayName) : '?';

      return GestureDetector(
        onTap: alreadyExists ? null : () => setState(() {
          if (isSelected) {
            _selectedContacts.remove(contact);
          } else {
            _selectedContacts.add(contact);
          }
        }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.14 : 0.05),
              blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            // Avatar — asset + overlay + initials
            Stack(clipBehavior: Clip.none, children: [
              Opacity(
                opacity: alreadyExists ? 0.65 : 1.0,
                child: contact.photoOrThumbnail != null
                    ? ClipOval(child: Image.memory(
                        contact.photoOrThumbnail!, width: 48, height: 48,
                        fit: BoxFit.cover))
                    : ClipOval(
                        child: SizedBox(width: 48, height: 48,
                          child: Stack(fit: StackFit.expand, children: [
                            Image.asset('assets/contact-icons/$avatarIndex.png',
                                fit: BoxFit.cover),
                            Container(color: Colors.black.withOpacity(
                                isDark ? 0.38 : 0.18)),
                            Center(child: Text(initials,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: [Shadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 4)]))),
                          ]))),
              ),
              if (alreadyExists)
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.lightPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBg, width: 1.5)),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 10))),
            ]),
            const SizedBox(width: 14),

            // Name + phone
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(contact.displayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: alreadyExists ? textS : textP),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (alreadyExists) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.lightPrimary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text('ALREADY IN NUDGE',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.lightPrimary,
                          letterSpacing: 0.3))),
                  ],
                ]),
                if (primaryPhone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(primaryPhone,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, color: textS)),
                ],
              ],
            )),
            const SizedBox(width: 12),

            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.lightPrimary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.lightPrimary
                      : alreadyExists
                          ? AppColors.lightPrimary.withOpacity(0.4)
                          : textS.withOpacity(0.35),
                  width: 1.5)),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : alreadyExists
                      ? Icon(Icons.check_rounded,
                          color: AppColors.lightPrimary.withOpacity(0.6), size: 14)
                      : null,
            ),
          ]),
        ),
      );
    }
  }

  class GroupSelectionDialog extends StatefulWidget {
    final List<SocialGroup> groups;

    const GroupSelectionDialog({super.key, required this.groups});

    @override
    State<GroupSelectionDialog> createState() => _GroupSelectionDialogState();
  }

  class _GroupSelectionDialogState extends State<GroupSelectionDialog> {
    String? _selectedGroupId;

    void _dismissKeyboard() {
      FocusScope.of(context).unfocus();
    }

    @override
    Widget build(BuildContext context) {
      final themeProvider = Provider.of<ThemeProvider>(context);
      final theme = Theme.of(context);
      
      return GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Dialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign to Group',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select which group these contacts belong to:',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.groups.length,
                    itemBuilder: (context, index) {
                      final group = widget.groups[index];
                      final isSelected = _selectedGroupId == group.id;
                      
                      return Card(
                        color: themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerHigh : Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(int.parse(group.colorCode.replaceAll('#', '0xFF'))),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            group.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : (Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                          subtitle: Text(
                            '${group.frequency} times ${group.period.toLowerCase()}',
                            style: TextStyle(
                              color: isSelected ? theme.colorScheme.primary : (themeProvider.isDarkMode ? Theme.of(context).colorScheme.surfaceContainerLow : Theme.of(context).colorScheme.outline),
                            ),
                          ),
                          trailing: isSelected 
                              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedGroupId = group.id;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedGroupId == null 
                            ? null 
                            : () {
                                final selectedGroup = widget.groups.firstWhere(
                                  (group) => group.id == _selectedGroupId,
                                );
                                Navigator.pop(context, selectedGroup);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Import Contacts',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

