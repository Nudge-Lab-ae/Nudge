// complete_profile_screen.dart - Enhanced with Social Universe Preview
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/screens/contacts/add_contact_screen.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:nudge/helpers/restart_helper.dart';
import 'package:nudge/widgets/social_universe_guide.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../contacts/import_contacts_screen.dart';

// Add these imports for contact picking functionality
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;
import '../../services/contact_sync_service.dart';
import '../../providers/theme_provider.dart';

// Import the Social Universe widget
import 'package:nudge/widgets/social_universe.dart';

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
  final List<Contact> _closeCircleContacts = [];
  final List<SocialGroup> _userGroups = [];

  // Country code
  CountryCode _selectedCountry = CountryCode(dialCode: '+971', code: 'AE');


  // Steps configuration - Updated with preview step
  final List<Map<String, dynamic>> _steps = [
    {'title': 'Complete Your Profile', 'subtitle': 'Tell us about yourself'},
    {'title': 'Create Social Groups', 'subtitle': 'Organize your contacts'},
    {'title': 'Welcome to Your Social Universe', 'subtitle': 'See what we\'re building'},
    {'title': 'Add Your Contacts', 'subtitle': 'Import or add contacts'},
    {'title': 'Identify Favourites', 'subtitle': 'Mark important relationships'},
    {'title': 'Review Setup', 'subtitle': 'You\'re all set!'},
  ];

  // Mock contacts for preview
  final List<Contact> _mockPreviewContacts = [
    Contact(
      id: 'preview_1',
      name: 'Alex Johnson',
      phoneNumber: '+1234567890',
      email: 'alex@example.com',
      priority: 1,
      notes: '',
      imageUrl: '',
      interactionHistory: {},
      connectionType: 'Friend',
      socialGroups: [],
      frequency: 2,
      period: 'Weekly',
      lastContacted: DateTime.now().subtract(const Duration(days: 3)),
      computedRing: 'inner',
      rawBand: 'inner',
      rawBandSince: DateTime.now().subtract(const Duration(days: 30)),
      cdi: 85,
      angleDeg: 45,
      isVIP: true,
      interactionCountInWindow: 12,
      tags: ['Close', 'Gym buddy'],
    ),
    Contact(
      id: 'preview_2',
      name: 'Sarah Miller',
      phoneNumber: '+1234567891',
      email: 'sarah@example.com',
      priority: 1,
      notes: '',
      imageUrl: '',
      interactionHistory: {},
      socialGroups: [],
      connectionType: 'Family',
      frequency: 1,
      period: 'Weekly',
      lastContacted: DateTime.now().subtract(const Duration(days: 7)),
      computedRing: 'inner',
      rawBand: 'inner',
      rawBandSince: DateTime.now().subtract(const Duration(days: 90)),
      cdi: 90,
      angleDeg: 120,
      isVIP: false,
      interactionCountInWindow: 8,
      tags: ['Sister', 'Emergency'],
    ),
    Contact(
      id: 'preview_3',
      name: 'Michael Chen',
      phoneNumber: '+1234567892',
      email: 'michael@example.com',
      priority: 1,
      notes: '',
      imageUrl: '',
      socialGroups: [],
      interactionHistory: {},connectionType: 'Colleague',
      frequency: 2,
      period: 'Monthly',
      lastContacted: DateTime.now().subtract(const Duration(days: 14)),
      computedRing: 'middle',
      rawBand: 'middle',
      rawBandSince: DateTime.now().subtract(const Duration(days: 60)),
      cdi: 65,
      angleDeg: 210,
      isVIP: false,
      interactionCountInWindow: 5,
      tags: ['Work', 'Project'],
    ),
    Contact(
      id: 'preview_4',
      name: 'David Wilson',
      phoneNumber: '+1234567893',
      email: 'david@example.com',
      priority: 1,
      notes: '',
      imageUrl: '',
      socialGroups: [],
      interactionHistory: {},
      connectionType: 'Client',
      frequency: 1,
      period: 'Quarterly',
      lastContacted: DateTime.now().subtract(const Duration(days: 45)),
      computedRing: 'outer',
      rawBand: 'outer',
      rawBandSince: DateTime.now().subtract(const Duration(days: 120)),
      cdi: 40,
      angleDeg: 300,
      isVIP: false,
      interactionCountInWindow: 2,
      tags: ['Business', 'Important'],
    ),
    Contact(
      id: 'preview_5',
      name: 'Emma Davis',
      phoneNumber: '+1234567894',
      email: 'emma@example.com',
      priority: 1,
      notes: '',
      imageUrl: '',
      socialGroups: [],
      interactionHistory: {},connectionType: 'Friend',
      frequency: 1,
      period: 'Monthly',
      lastContacted: DateTime.now().subtract(const Duration(days: 21)),
      computedRing: 'middle',
      rawBand: 'middle',
      rawBandSince: DateTime.now().subtract(const Duration(days: 75)),
      cdi: 55,
      angleDeg: 150,
      isVIP: false,
      interactionCountInWindow: 4,
      tags: ['College', 'Travel'],
    ),
    Contact(
      id: 'preview_6',
      name: 'Robert Taylor',
      phoneNumber: '+1234567895',
      email: 'robert@example.com',
       priority: 1,
      notes: '',
      imageUrl: '',
      socialGroups: [],
      interactionHistory: {},connectionType: 'Mentor',
      frequency: 2,
      period: 'Annually',
      lastContacted: DateTime.now().subtract(const Duration(days: 90)),
      computedRing: 'outer',
      rawBand: 'outer',
      rawBandSince: DateTime.now().subtract(const Duration(days: 180)),
      cdi: 35,
      angleDeg: 30,
      isVIP: true,
      interactionCountInWindow: 1,
      tags: ['Advisor', 'Expert'],
    ),
    Contact(
      id: 'preview_7',
      name: 'Lisa Brown',
      phoneNumber: '+1234567896',
      email: 'lisa@example.com',
      connectionType: 'Family',
      priority: 1,
      notes: '',
      imageUrl: '',
      socialGroups: [],
      interactionHistory: {},
      frequency: 3,
      period: 'Weekly',
      lastContacted: DateTime.now().subtract(const Duration(days: 1)),
      computedRing: 'inner',
      rawBand: 'inner',
      rawBandSince: DateTime.now().subtract(const Duration(days: 365)),
      cdi: 95,
      angleDeg: 75,
      isVIP: false,
      interactionCountInWindow: 15,
      tags: ['Mother', 'Close'],
    ),
    Contact(
      id: 'preview_8',
      name: 'James Wilson',
      phoneNumber: '+1234567897',
      email: 'james@example.com',
      connectionType: 'Colleague',
      priority: 1,
      notes: '',
      imageUrl: '',
      socialGroups: [],
      interactionHistory: {},frequency: 1,
      period: 'Monthly',
      lastContacted: DateTime.now().subtract(const Duration(days: 28)),
      computedRing: 'outer',
      rawBand: 'outer',
      rawBandSince: DateTime.now().subtract(const Duration(days: 150)),
      cdi: 30,
      angleDeg: 250,
      isVIP: false,
      interactionCountInWindow: 3,
      tags: ['Work', 'Team'],
    ),
  ];

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

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
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

  Future<void> _completeOnboarding() async {
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
         _showSocialUniverseGuide(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  // In the _CompleteProfileScreenState class, add this method:
    void _showSocialUniverseGuide(BuildContext context) {
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
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
            isDarkMode: false,
          ),
        );
      },
    );
  }



  void _navigateToDashboardWithSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Onboarding Complete!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _selectedContacts.isNotEmpty 
                        ? 'Your first nudges have been scheduled'
                        : 'You can add contacts and schedule nudges anytime',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      AppRestartHelper.setSkipSplashFlag();
      AppRestartHelper.forceAppRestart(context);
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
    // Don't show step indicator on preview screen (step 2)
    // if (_currentStep == 2) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.only(top: 16, bottom: 16, right: 16, left: 16),
      decoration: BoxDecoration(
        color: themeProvider.getSurfaceColor(context),
        border: Border(
          bottom: BorderSide(
            color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Column(
        children: [
          // Staggered (broken) lines indicator
          Container(
            height: 6,
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (index) {
                // Only show lines up to current step
                bool isActive = index <= _currentStep;
                bool isLast = index == _steps.length - 1;
                
                return Row(
                  children: [
                    // Line segment
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xff3CB3E9) : (themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey[300]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Gap between lines (except after last line)
                    if (!isLast) const SizedBox(width: 8),
                  ],
                );
              }),
            ),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of ${_steps.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff3CB3E9),
                ),
              ),
              Text(
                _steps[_currentStep]['title'],
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
              ),
            ],
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
      case 1: return _buildPreviewStep();
      case 2: return _buildGroupsStep();
      case 3: return _buildContactsStep();
      case 4: return _buildCloseCircleStep();
      case 5: return _buildReviewStep();
      default: return _buildProfileStep();
    }
  }

  // NEW: Preview Step with Social Universe
  Widget _buildPreviewStep() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final theme = Theme.of(context);
    
    return Expanded(
      child: ListView(
        padding: EdgeInsets.zero,
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          Container(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 40),
            child: Column(
              children: [
                Text(
                  'Welcome to',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 15, 57, 142), // Navy blue color
                  ),
                ),
                Text(
                  'Your Social Universe',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 15, 57, 142), // Navy blue color
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Visualize your connections like never before',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          // Social Universe Preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 350,
                  color: themeProvider.isDarkMode ? Colors.black : const Color(0xFF0A1A3B),
                  child: SocialUniverseWidget(
                    contacts: _mockPreviewContacts,
                    showTitle: false,
                    onContactView: (contact) {
                      // Preview interaction
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('In your actual Social Universe, you can view details for ${contact.name}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    height: 350,
                    isImmersive: false,
                    isDarkMode: themeProvider.isDarkMode,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Features list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFeatureItem(
                  Icons.star,
                  'Visualize Connections',
                  'See your relationships in beautiful rings',
                  themeProvider,
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  Icons.notifications,
                  'Smart Reminders',
                  'Never lose touch with important people',
                  themeProvider,
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  Icons.group,
                  'Organize Groups',
                  'Categorize contacts by relationship type',
                  themeProvider,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Call to action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(
                //   'Customize your social universe in a few easy steps',
                //   style: TextStyle(
                //     fontSize: 20,
                //     fontWeight: FontWeight.w700,
                //     color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                //   ),
                // ),
                const SizedBox(height: 8),
                Text(
                  'Let\'s build a Social Universe customized to you',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, ThemeProvider themeProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xff3CB3E9).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xff3CB3E9),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final updatedContacts = await apiService.getAllContacts();
        setState(() {
          _selectedContacts = updatedContacts;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported contacts to ${group.name}!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import contacts: ${result['message']}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing contacts: $e')),
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
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
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
                    backgroundColor: const Color(0xff3CB3E9),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Save Crop', style: TextStyle(color: Colors.white)),
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
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                  'Start by telling us about yourself',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
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
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Username
            Text('USERNAME *', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555), fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              textCapitalization: TextCapitalization.words,
              onTap: () => _dismissKeyboard(),
              style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Enter your username',
                hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                fillColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                filled: true,
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please enter a username' : null,
              onChanged: onUserNameChange,
            ),
            const SizedBox(height: 20),
            
            // Phone Number with Country Code
            Text('PHONE NUMBER *', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555), fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                      borderRadius: BorderRadius.circular(10),
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
                      textStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                      searchStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                      dialogTextStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                      dialogBackgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                    style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Phone number',
                      hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xff3CB3E9), width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      errorStyle: const TextStyle(fontSize: 12),
                      fillColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
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
            Text('BIO', style: TextStyle(fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555), fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              onTap: () => _dismissKeyboard(),
              style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Tell us a bit about yourself...',
                hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                fillColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
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
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create groups to categorize your relationships.\n1. Add, edit or remove groups\n2. Drag to reorder groups by priority',
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // Add new group button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addNewGroup,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add New Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff3CB3E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Reorderable list of groups
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
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
              // This is important - it ensures the drag handle works correctly
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
    
    return Container(
      key: Key(group.id),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border.all(
          color: themeProvider.isDarkMode 
              ? Colors.grey.shade800 
              : const Color.fromARGB(255, 206, 203, 203), 
          width: 1
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with drag handle and delete button
            Row(
              children: [
                // Wrap the drag handle in a SizedBox with explicit size
                ReorderableDragStartListener(
                  index: index,
                  child: Row(
                    children: [
                      Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.drag_handle, 
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade400 
                          : Colors.grey,
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Text(
                    'Drag to reorder',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.isDarkMode 
                          ? Colors.grey.shade500 
                          : Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  )]),
                ),
                Expanded(
                  child: Center(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteGroup(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Group name field
            TextFormField(
              initialValue: group.name,
              onTap: () => _dismissKeyboard(),
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black
              ),
              decoration: InputDecoration(
                labelText: 'GROUP NAME',
                labelStyle: TextStyle(
                  color: themeProvider.isDarkMode 
                      ? Colors.grey.shade400 
                      : const Color(0xff555555)
                ),
                border: const OutlineInputBorder(),
                isDense: true,
                filled: true,
                fillColor: themeProvider.isDarkMode 
                    ? Colors.grey.shade800 
                    : Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() {
                  _userGroups[index] = group.copyWith(name: value);
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Contact Frequency Dropdown
            DropdownButtonFormField<String>(
              value: _getCurrentFrequencyChoice(group),
              onTap: () => _dismissKeyboard(),
              style: TextStyle(
                color: themeProvider.isDarkMode 
                    ? Colors.white 
                    : const Color(0xff555555)
              ),
              decoration: InputDecoration(
                labelText: 'CONTACT FREQUENCY',
                labelStyle: TextStyle(
                  color: themeProvider.isDarkMode 
                      ? Colors.grey.shade400 
                      : const Color(0xff555555)
                ),
                border: const OutlineInputBorder(),
                isDense: true,
                filled: true,
                fillColor: themeProvider.isDarkMode 
                    ? Colors.grey.shade800 
                    : Colors.grey.shade50,
              ),
              items: FrequencyPeriodMapper.frequencyMapping.keys.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value, 
                    style: TextStyle(
                      color: themeProvider.isDarkMode 
                          ? Colors.white 
                          : const Color(0xff555555)
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
    );
  }

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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.red.shade600, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _phoneController.text.length < 9 
                  ? 'Phone number too short. Must be exactly 9 digits.' 
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff3CB3E9).withOpacity(0.3)),
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
                color: Color(0xff3CB3E9),
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
      _userGroups.add(SocialGroup(
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
        orderIndex: _userGroups.length
      ));
    });
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added a new group at the bottom.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
  }

  void _deleteGroup(int index) {
    _dismissKeyboard();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text('Delete Group', style: TextStyle(color: Color(0xff777777)),),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
                'Let\'s fill your Social Universe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              // Text(
              //   'Add contacts to start building your universe',
              //   style: TextStyle(
              //     fontSize: 16,
              //     color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 30),
          
          Text('ADD YOUR CONTACTS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
          const SizedBox(height: 10),
          Text('Import your contacts or add them manually. You can skip this and do it later.', 
            style: TextStyle(fontSize: 14, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey), textAlign: TextAlign.center),
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
            color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
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
                            Icon(Icons.person_add_alt_1, size: 50, color: const Color(0xff3CB3E9)),
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
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff3CB3E9),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: const Text('Add New', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create from scratch',
                              style: TextStyle(
                                fontSize: 12,
                                color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.contacts, size: 50, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                _dismissKeyboard();
                                _pickContactsManually();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xff3CB3E9),
                                side: const BorderSide(color: Color(0xff3CB3E9)),
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
                                color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey,
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
            Card(
              color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUICK IMPORT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Import your existing contacts from device',
                      style: TextStyle(
                        color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        _dismissKeyboard();
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImportContactsScreen(
                              groups: _getOrderedGroupsForSelection(),
                              isOnboarding: true,
                            ),
                          ),
                        );
                        
                        if (result != null && result is List<Contact>) {
                          final Set<String> existingIds = _selectedContacts.map((c) => c.id).toSet();
                          final List<Contact> newContacts = result.where((c) => !existingIds.contains(c.id)).toList();
                          
                          setState(() {
                            _selectedContacts.addAll(newContacts);
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff3CB3E9),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Import Contacts', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Add Contacts Card (same as iOS but for Android)
            Card(
              color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
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
                              Icon(Icons.person_add_alt_1, size: 50, color: const Color(0xff3CB3E9)),
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
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff3CB3E9),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                child: const Text('Add New', style: TextStyle(color: Colors.white, fontSize: 14)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create from scratch',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              Icon(Icons.contacts, size: 50, color: Color(0xff3CB3E9)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () {
                                  _dismissKeyboard();
                                  _pickContactsManually();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xff3CB3E9),
                                  side: const BorderSide(color: Color(0xff3CB3E9)),
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
                                  color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey,
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

      List<SocialGroup> _getOrderedGroupsForSelection() {
        return List.from(_userGroups);
      }

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
                child: Text('Identify Your Favourites', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
              ),
              const SizedBox(height: 10),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
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
                      style: TextStyle(fontSize: 14, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              if (_selectedContacts.isNotEmpty) ...[
                Text('Select your Favourites members:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                const SizedBox(height: 10),
                
                ..._selectedContacts.map((contact) => Card(
                  color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    title: Text(contact.name, style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                    subtitle: contact.phoneNumber.isNotEmpty ? Text(contact.phoneNumber, style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)) : null,
                    secondary: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                    ),
                    value: _closeCircleContacts.contains(contact),
                    onChanged: (bool? value) => _toggleCloseCircleContact(contact),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                )).toList(),
              ] else ...[
                Card(
                  color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Icon(Icons.people_outline, size: 60, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                      const SizedBox(height: 16),
                      Text('No Contacts Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                      const SizedBox(height: 8),
                      Text('You haven\'t added any contacts yet. You can add them later from the dashboard.', textAlign: TextAlign.center, style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        );
      }

      Widget _buildReviewStep() {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final theme = Theme.of(context);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 50, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text('Your Social Universe is Ready! 🎉', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black), textAlign: TextAlign.center,),
                  const SizedBox(height: 16),
                  Text(
                    'We\'ve created your groups and scheduled your first nudges. You\'ll start seeing reminders soon — and get your first Weekly Digest this Sunday!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey, height: 1.5),
                  ),
                ]),
              ),
              
              const SizedBox(height: 40),
              Text('Your Nudge Setup:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
              const SizedBox(height: 20),
              
              _buildSummaryItem(Icons.person, 'Profile Complete', 'Username: ${_usernameController.text}'),
              _buildSummaryItem(Icons.group, '${_userGroups.length} Social Groups', 'Organized by priority'),
              _buildSummaryItem(Icons.contacts, 'Contacts', 'You can add contacts later from the dashboard'),
              _buildSummaryItem(Icons.star, 'Favourites', '${_closeCircleContacts.length} important relationships'),
              // _buildSummaryItem(Icons.notifications, 'Weekly Digest', 'Starting this Sunday'),
              
              const SizedBox(height: 40),
              
              // Preview of what's next
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Explore Your Social Universe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Visit your dashboard to explore your personalized Social Universe visualization and manage your connections.',
                      style: TextStyle(
                        color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        );
      }

      Widget _buildSummaryItem(IconData icon, String title, String subtitle) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final theme = Theme.of(context);
        
        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
          subtitle: Text(subtitle, style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)),
        );
      }

      @override
      Widget build(BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final theme = Theme.of(context);
        
        return GestureDetector(
          onTap: _dismissKeyboard,
          behavior: HitTestBehavior.translucent,
          child: Scaffold(
            backgroundColor: themeProvider.getBackgroundColor(context),
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
                  backgroundColor: themeProvider.getSurfaceColor(context),
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
                  color: themeProvider.getSurfaceColor(context),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
                  border: Border(
                    top: BorderSide(
                      color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Back', style: TextStyle(fontSize: _currentStep == _steps.length - 1 ? 14 : 16,),),
                    ),
                  ),
                  if (_currentStep > 0) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    autofocus: true,
                    onPressed: () {
                      print('trying to continue');
                      _dismissKeyboard();
                      
                      // Handle each step's validation
                      if (_currentStep == 0) {
                        // Profile step - validate form
                        if (_formKey.currentState!.validate()) {
                          _nextStep();
                        }
                      } else if (_currentStep == 1) {
                        // Groups step - just check if groups exist
                        if (_userGroups.isNotEmpty) {
                          _nextStep();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please add at least one group'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        // All other steps (preview, contacts, close circle, review) - just continue
                        _nextStep();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _currentStep == _steps.length - 1 
                              ? 'Launch Your Universe' 
                              : 'Continue',
                            style: TextStyle(fontSize: _currentStep == _steps.length - 1 ? 14 :16, fontWeight: FontWeight.bold, color: Colors.white),
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
          .map((phone) => _normalizePhoneNumber(phone.normalizedNumber))
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
      final theme = Theme.of(context);
      
      return GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: themeProvider.getBackgroundColor(context),
          appBar: AppBar(
            title: Text(
              'SELECT CONTACTS', 
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: themeProvider.getSurfaceColor(context),
            actions: [
              IconButton(
                icon: Icon(Icons.select_all, color: themeProvider.getTextPrimaryColor(context)),
                tooltip: 'Select all',
                onPressed: _selectAll,
              ),
              IconButton(
                icon: Icon(Icons.clear, color: themeProvider.getTextPrimaryColor(context)),
                tooltip: 'Clear selection',
                onPressed: _clearSelection,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Text(
                    '${_selectedContacts.length}',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onTap: () => _dismissKeyboard(),
                  style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search by name, phone, or email...',
                    hintStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                  ),
                  onChanged: _applyFilter,
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredContacts.length} contacts found',
                      style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                    ),
                    Text(
                      '${widget.existingContacts.length} already in Nudge',
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              Expanded(
                child: _filteredContacts.isEmpty
                    ? Center(
                        child: Text(
                          'No contacts found',
                          style: TextStyle(fontSize: 16, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final isSelected = _selectedContacts.contains(contact);
                          final alreadyExists = _isContactAlreadyExists(contact);
                          
                          final primaryPhone = contact.phones.isNotEmpty
                              ? contact.phones.first.number
                              : '';
                          final primaryEmail = contact.emails.isNotEmpty
                              ? contact.emails.first.address
                              : '';
                          
                          final avatarIndex = _getAvatarIndex(contact);
                          
                          // Determine text color based on contact state
                          Color textColor;
                          Color subtitleColor;
                          
                          if (alreadyExists) {
                            textColor = themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade500;
                            subtitleColor = themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
                          } else if (isSelected) {
                            textColor = theme.colorScheme.primary;
                            subtitleColor = theme.colorScheme.primary.withOpacity(0.8);
                          } else {
                            textColor = themeProvider.isDarkMode ? Colors.white : Colors.black;
                            subtitleColor = themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey;
                          }

                          Widget avatar;
                          if (contact.photoOrThumbnail != null) {
                            avatar = CircleAvatar(
                              backgroundImage: MemoryImage(contact.photoOrThumbnail!),
                              radius: 24,
                            );
                          } else {
                            avatar = CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.transparent,
                              backgroundImage: AssetImage('assets/contact-icons/$avatarIndex.png'),
                              child: Opacity(
                                opacity: alreadyExists ? 0.5 : 1.0,
                                child: Text(
                                  contact.displayName.isNotEmpty ? _getContactInitials(contact.displayName).toUpperCase() : '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }
                          
                          return Container(
                            color: isSelected && !alreadyExists
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                            child: ListTile(
                              leading: Opacity(
                                opacity: alreadyExists ? 0.5 : 1.0,
                                child: avatar,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      contact.displayName,
                                      style: TextStyle(
                                        fontWeight: isSelected && !alreadyExists ? FontWeight.bold : FontWeight.normal,
                                        color: textColor,
                                        fontStyle: alreadyExists ? FontStyle.italic : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                  if (alreadyExists)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: themeProvider.isDarkMode 
                                            ? Colors.grey.shade800 
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Already in Nudge',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: themeProvider.isDarkMode 
                                              ? Colors.grey.shade400 
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (primaryPhone.isNotEmpty) 
                                    Text(
                                      primaryPhone, 
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontStyle: alreadyExists ? FontStyle.italic : FontStyle.normal,
                                      ),
                                    ),
                                  if (primaryEmail.isNotEmpty) 
                                    Text(
                                      primaryEmail, 
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontStyle: alreadyExists ? FontStyle.italic : FontStyle.normal,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isSelected && !alreadyExists
                                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                                  : alreadyExists
                                      ? Icon(Icons.check_circle_outline, color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400)
                                      : null,
                              onTap: alreadyExists
                                  ? null // Make already existing contacts unselectable
                                  : () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedContacts.remove(contact);
                                        } else {
                                          _selectedContacts.add(contact);
                                        }
                                      });
                                    },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.getSurfaceColor(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
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
                    onPressed: _selectedContacts.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedContacts),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Import (${_selectedContacts.length})',
                      style: const TextStyle(color: Colors.white),
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
          backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign to Group',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select which group these contacts belong to:',
                  style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
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
                        color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
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
                              color: isSelected ? theme.colorScheme.primary : (themeProvider.isDarkMode ? Colors.white : Colors.black),
                            ),
                          ),
                          subtitle: Text(
                            '${group.frequency} times ${group.period.toLowerCase()}',
                            style: TextStyle(
                              color: isSelected ? theme.colorScheme.primary : (themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
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
                        child: const Text(
                          'Import Contacts',
                          style: TextStyle(color: Colors.white, fontSize: 14),
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

