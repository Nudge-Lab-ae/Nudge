// complete_profile_screen.dart - Updated with crop_your_image
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
// import 'package:nudge/services/nudge_service.dart';
// import 'package:nudge/models/user.dart';
// import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:nudge/helpers/restart_helper.dart';
import 'package:provider/provider.dart';
import 'dart:io';
// import 'dart:ui' as ui;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../contacts/import_contacts_screen.dart';
// import '../dashboard/dashboard_screen.dart';

// Add these imports for contact picking functionality
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;
import '../../services/contact_sync_service.dart';
import '../../providers/theme_provider.dart';

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
  // File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  // Uint8List? _croppedData;
  String myUsername = '';
  String myPhone = '';
  String myBio = '';
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
  // String _countryCode = '+971';
  CountryCode _selectedCountry = CountryCode(dialCode: '+971', code: 'AE');


  // Steps configuration
  final List<Map<String, dynamic>> _steps = [
    {'title': 'Complete Your Profile', 'subtitle': 'Tell us about yourself'},
    {'title': 'Create Social Groups', 'subtitle': 'Organize your contacts'},
    {'title': 'Add Your Contacts', 'subtitle': 'Import or add contacts'},
    {'title': 'Identify Close Circle', 'subtitle': 'Mark important relationships'},
    {'title': 'Review Setup', 'subtitle': 'You\'re all set!'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeDefaultGroups();
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
    // if (cropped!=null) {
    //   // Create a temporary file from cropped bytes
     
    // }
     final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_imageBytes!.toList());
      
      setState(() {
        // _imageFile = file;
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

  // Helper method to get temporary directory
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

  bool _isStepValid(int step) {
    switch (step) {
      case 0: // Profile
        return myUsername.isNotEmpty && 
              myPhone.isNotEmpty && 
              _isValidPhoneNumber(myPhone);
      case 1: // Groups
        return _userGroups.isNotEmpty;
      case 2: // Contacts
        return true; // Changed: Allow continuing without contacts
      case 3: // Close Circle
        return true;
      case 4: // Review
        return true;
      default:
        return false;
    }
  }

  Future<String> uploadImageToFirebase(Uint8List imageBytes, String fileName) async {
    try {
      // Reference to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref();

      // Create a child reference (folder + filename)
      final imagesRef = storageRef.child('uploads/$fileName');

      // Upload raw data
      UploadTask uploadTask = imagesRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/png'), // or 'image/jpeg'
      );

      // Wait until upload completes
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
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
        // STEP 1: Ensure FCM token is stored before anything else
        print('storing token');
        await authService.storeFCMToken();
        
        // STEP 2: Get fresh user data with FCM token
        final freshUserDoc = await apiService.getUser();
        final freshUserMap = freshUserDoc.toMap();
        if (freshUserMap['fcmToken'] == null || freshUserMap['fcmToken'].isEmpty) {
          // Try to get token again if not available
          print('getting token');
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await apiService.updateUser({'fcmToken': fcmToken});
          } else {
            throw Exception('FCM token is required for notifications');
          }
        } else{
          print('got token already');
        }

        // Upload image if selected
        String imageUrl = '';
        if (_imageBytes != null) {
          String uniqueID = _usernameController.text + (DateTime.now().millisecondsSinceEpoch).toString();
          imageUrl = await uploadImageToFirebase(_imageBytes!, uniqueID);
        }

        print('Final Stage 1');
        
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
        
        print('Final Stage 2');
        // Save groups
        await apiService.updateGroups(_userGroups);

        if (_closeCircleContacts.isNotEmpty) {
          await apiService.updateCloseCircleContacts(_closeCircleContacts);
        }

        print('Final Stage 3');

        if (_selectedContacts.isNotEmpty) {
          // Schedule nudges in background without waiting
          //  apiService.scheduleHourlyNotifications();
           apiService.scheduleRegularNotifications();
          // _scheduleNudgesForImportedContacts();
        }
        
        print('Final Stage 4');
        
        // Navigate to dashboard using restart approach
        _navigateToDashboardWithSuccess();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboardWithSuccess() {
    // Show success message
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

    // Force app restart after a delay to show the snackbar
    Future.delayed(const Duration(milliseconds: 1500), () {
      AppRestartHelper.setSkipSplashFlag();
      AppRestartHelper.forceAppRestart(context);
    });
  }

  void _toggleCloseCircleContact(Contact contact) {
    print(contact.toMap()); print(' is the contact');
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

  // Use full screen instead of dialog
  final selectedContacts = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ContactPickerDialog(contacts: contacts),
    ),
  );

  if (selectedContacts == null || selectedContacts.isEmpty) return;

  // Show group selection dialog
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: constraints.maxWidth * ((_currentStep + 1) / _steps.length),
                      decoration: BoxDecoration(
                        color: const Color(0xff3CB3E9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
      case 1: return _buildGroupsStep();
      case 2: return _buildContactsStep();
      case 3: return _buildCloseCircleStep();
      case 4: return _buildReviewStep();
      default: return _buildProfileStep();
    }
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
      // Import contacts and assign to the selected group
      final result = await syncService.importContactsWithGroup(
        pickedContacts: deviceContacts,
        groupId: group.name,
        onProgress: (processed, total) {
          // Progress callback if needed
        },
      );

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        // Update the selected contacts list
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
      myUsername = username;
    });
  }

  onPhoneChange(String phone) {
    setState(() {
      myPhone = phone;
    });
  }

  onBioChange(String bio) {
    setState(() {
      myBio = bio;
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
                    // initialArea: Rect.largest,
                     onCropped: (result) {
                            switch (result) {
                              case CropSuccess(:final croppedImage):
                                // _croppedData = croppedImage;
                                _imageBytes = croppedImage;
                              case CropFailure(:final cause):
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Error'),
                                    content:
                                        Text('Failed to crop image: ${cause}'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text('OK')),
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
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
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
                      initialSelection: _selectedCountry.code, // Use current selection
                      favorite: [_selectedCountry.code!, 'US'], // Preserve current as favorite
                      showCountryOnly: false,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      // Key to force rebuild when selection changes
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
                    maxLength: 9,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // Only allow digits
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
                      // Validate on the fly
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
    );
  }

Widget _buildGroupsStep() {
  final themeProvider = Provider.of<ThemeProvider>(context);
  // final theme = Theme.of(context);
  
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('CUSTOMIZE YOUR SOCIAL GROUPS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
        const SizedBox(height: 10),
        Text('Drag to reorder groups by priority. Add, edit, or remove groups.', 
          style: TextStyle(fontSize: 14, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)),
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
            border: Border.all(color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userGroups.length,
            itemBuilder: (context, index) {
              final group = _userGroups[index];
              return Container(
                key: Key(group.id),
                decoration: BoxDecoration(
                  border: index < _userGroups.length - 1 
                      ? Border(bottom: BorderSide(color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200))
                      : null,
                ),
                child: _buildEditableGroupItem(group, index),
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = _userGroups.removeAt(oldIndex);
                _userGroups.insert(newIndex, item);
                
                // Update orderIndex for all groups
                for (int i = 0; i < _userGroups.length; i++) {
                  _userGroups[i] = _userGroups[i].copyWith(orderIndex: i);
                }
              });
            },
          ),
        ),
        const SizedBox(height: 40),
      ],
    ),
  );
}

// Update the _buildEditableGroupItem to include drag handle
  Widget _buildEditableGroupItem(SocialGroup group, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with drag handle and delete
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_handle, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: group.name,
                  onTap: () => _dismissKeyboard(),
                  style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'GROUP NAME',
                    labelStyle: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xff555555)),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _userGroups[index] = group.copyWith(name: value);
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteGroup(index),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          // Frequency Dropdown
          Text('CONTACT FREQUENCY:', style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
          const SizedBox(height: 8),
         DropdownButtonFormField<String>(
            value: _getCurrentFrequencyChoice(group),
            onTap: () => _dismissKeyboard(),
            style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              filled: true,
              fillColor: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
            ),
            items: FrequencyPeriodMapper.frequencyMapping.keys.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),),
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
          
          const SizedBox(height: 20),
          
          // Members section
          Text(
            '${group.memberIds.length} members',
            style: TextStyle(
              color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentFrequencyChoice(SocialGroup group) {
    return FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period);
  }

  bool _isValidPhoneNumber(String phone) {
    // Remove any spaces, dashes, or parentheses
    String cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's exactly 9 digits and only numbers
    if (cleanedPhone.length != 9) {
      return false;
    }
    
    // Check if all characters are digits
    if (!RegExp(r'^[0-9]{9}$').hasMatch(cleanedPhone)) {
      return false;
    }
    
    return true;
  }

    Widget _buildPhoneValidationMessage() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (myPhone.isEmpty) {
      return const SizedBox.shrink();
    }
    
    if (!_isValidPhoneNumber(myPhone)) {
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
                myPhone.length < 9 
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
              'Valid phone number: ${_selectedCountry.dialCode} ${myPhone}',
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
        frequency: 2, // Default frequency
        memberIds: [],
        memberCount: 0,
        lastInteraction: DateTime.now(),
        colorCode: '#2596BE',
        birthdayNudgesEnabled: true, // Default enabled
        anniversaryNudgesEnabled: true, // Default enabled
        orderIndex: _userGroups.length
      ));
    });
  }

  void _deleteGroup(int index) {
    _dismissKeyboard();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
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
    var size = MediaQuery.of(context).size;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text('ADD YOUR CONTACTS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555))),
          const SizedBox(height: 10),
          Text('Import your contacts or add them manually. You can skip this and do it later.', 
            style: TextStyle(fontSize: 14, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          
          // Import Options - Fixed layout
          Platform.isIOS
          ? Container(
            width: size.width*0.7,
            height: size.height*0.4,
            child: Card(
              color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
              child: Padding(
                 padding: const EdgeInsets.only(left: 5, right: 5, bottom: 20, top: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add, size: 60, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                    const SizedBox(height: 16),
                    Text('ADD MANUALLY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                    const SizedBox(height: 8),
                    Text('Select specific contacts to import', 
                      textAlign: TextAlign.center, style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () {
                        _dismissKeyboard();
                        _pickContactsManually();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff3CB3E9),
                        side: const BorderSide(color: Color(0xff3CB3E9)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Pick Contacts', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          )
          : Row(
            children: [
              Expanded(
                child: Card(
                  color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5, right: 5, bottom: 20, top: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.import_contacts, size: 60, color: const Color(0xff3CB3E9)),
                        const SizedBox(height: 16),
                        Text('QUICK IMPORT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                        const SizedBox(height: 8),
                        Text('Import your existing contacts', 
                          textAlign: TextAlign.center, style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            _dismissKeyboard();
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>  ImportContactsScreen(
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
                          child: const Text('Import Contacts', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                  child: Padding(
                     padding: const EdgeInsets.only(left: 5, right: 5, bottom: 20, top: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add, size: 60, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                        const SizedBox(height: 16),
                        Text('ADD MANUALLY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                        const SizedBox(height: 8),
                        Text('Select specific contacts to import', 
                          textAlign: TextAlign.center, style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)),
                        const SizedBox(height: 20),
                        OutlinedButton(
                          onPressed: () {
                            _dismissKeyboard();
                            _pickContactsManually();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff3CB3E9),
                            side: const BorderSide(color: Color(0xff3CB3E9)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Pick Contacts', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<SocialGroup> _getOrderedGroupsForSelection() {
    // Return groups in their current UI order (after any reordering)
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
          Text('Identify Your Close Circle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 10),
          
          // Explanation
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
                  Text('What is a Close Circle?', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Your Close Circle is for people you naturally connect with often — those relationships don\'t need reminders. NUDGE will include them in your weekly reflection so you can note how things are going.',
                  style: TextStyle(fontSize: 14, color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Contact Selection
          if (_selectedContacts.isNotEmpty) ...[
            Text('Select your Close Circle members:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
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
              Text('You\'re all set! 🎉', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
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
          _buildSummaryItem(Icons.star, 'Close Circle', '${_closeCircleContacts.length} important relationships'),
          _buildSummaryItem(Icons.notifications, 'Weekly Digest', 'Starting this Sunday'),
          
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
          title: GradientText( text: 'NUDGE', style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
               gradient: const LinearGradient(
                  colors: [Color(0xFF5CDEE5), Color(0xFF2D85F6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
            ),
          ),
          centerTitle: true,
          backgroundColor: themeProvider.getSurfaceColor(context),
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false, // Remove back button
          elevation: 0,
        ),
        body: Column(children: [
          if (!_isCropping) _buildStepIndicator(themeProvider),
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
              if (_currentStep > 0) Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Back'),
                ),
              ),
              if (_currentStep > 0) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    _dismissKeyboard();
                    if (_currentStep == 0) {
                      // Validate form for profile step
                      if (_formKey.currentState!.validate()) {
                        _nextStep();
                      }
                    } else if (_isStepValid(_currentStep)) {
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
                      : Text(_currentStep == _steps.length - 1 ? 'Go to Dashboard' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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

  const ContactPickerDialog({super.key, required this.contacts});

  @override
  State<ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<ContactPickerDialog> {
  final List<fContacts.Contact> _selectedContacts = [];
  final TextEditingController _searchController = TextEditingController();
  List<fContacts.Contact> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
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
      _selectedContacts.addAll(_filteredContacts);
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
          title: Text('SELECT CONTACTS', style: TextStyle(color: themeProvider.isDarkMode ? Colors.white : const Color(0xff555555)),),
          backgroundColor: themeProvider.getSurfaceColor(context),
          actions: [
            // Selection info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '${_selectedContacts.length} selected',
                  style: TextStyle(fontSize: 16, color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
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
            
            // Selection actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredContacts.length} contacts found',
                    style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _selectAll,
                        child: Text('Select All', style: TextStyle(color: theme.colorScheme.primary)),
                      ),
                      TextButton(
                        onPressed: _clearSelection,
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Contacts list
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
                        
                        // Extract contact information
                        final primaryPhone = contact.phones.isNotEmpty
                            ? contact.phones.first.number
                            : '';
                        final primaryEmail = contact.emails.isNotEmpty
                            ? contact.emails.first.address
                            : '';
                        
                        return Card(
                          color: themeProvider.isDarkMode ? Colors.grey.shade900 : Colors.white,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: CheckboxListTile(
                            title: Text(
                              contact.displayName,
                              style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.isDarkMode ? Colors.white : Colors.black),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (primaryPhone.isNotEmpty) 
                                  Text(primaryPhone, style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)),
                                if (primaryEmail.isNotEmpty) 
                                  Text(primaryEmail, style: TextStyle(color: themeProvider.isDarkMode ? Colors.grey.shade400 : Colors.grey)),
                              ],
                            ),
                            secondary: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: contact.photoOrThumbnail != null
                                  ? ClipOval(
                                      child: Image.memory(
                                        contact.photoOrThumbnail!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Text(
                                      contact.displayName.isNotEmpty 
                                          ? contact.displayName[0].toUpperCase() 
                                          : '?',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                            ),
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedContacts.add(contact);
                                } else {
                                  _selectedContacts.remove(contact);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
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
              
              // Group selection list
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
              
              // Action buttons
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