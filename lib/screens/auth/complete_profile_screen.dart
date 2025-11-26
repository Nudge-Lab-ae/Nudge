// complete_profile_screen.dart - Updated with crop_your_image
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/services/nudge_service.dart';
// import 'package:nudge/models/user.dart';
// import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import 'dart:io';
// import 'dart:ui' as ui;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../contacts/import_contacts_screen.dart';
import '../dashboard/dashboard_screen.dart';

// Add these imports for contact picking functionality
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;
import '../../services/contact_sync_service.dart';

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

void _initializeDefaultGroups() {
  _userGroups.addAll([
    SocialGroup(
      id: 'family', 
      name: 'Family', 
      frequency: 4,
      period: 'Monthly',
      colorCode: '#4FC3F7', 
      description: '', 
      memberCount: 0, 
      memberIds: [], 
      lastInteraction: DateTime.now(), 
      birthdayNudgesEnabled: true,
      anniversaryNudgesEnabled: true,
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
    ),
    SocialGroup(
      id: 'mentor', 
      name: 'Mentor', 
      frequency: 2,
      period: 'Yearly',
      colorCode: '#607D8B', 
      description: '', 
      memberCount: 0, 
      memberIds: [], 
      lastInteraction: DateTime.now(), 
      birthdayNudgesEnabled: true,
      anniversaryNudgesEnabled: true,
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
        return myUsername.isNotEmpty && myPhone.isNotEmpty;
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
        // Upload image if selected
        String imageUrl = '';
        if (_imageBytes != null) {
          // Implement image upload logic here
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
          // Schedule nudges in background without waiting
          _scheduleNudgesForImportedContacts();
        }
        // Navigate to dashboard
        // Navigator.pushReplacement(
        //   context, 
        //   MaterialPageRoute(builder: (context) => const DashboardScreen()),
        // );
         _navigateToDashboardWithSuccess();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboardWithSuccess() {
  // Show success message before navigation
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

  // Navigate after showing the message
  Future.delayed(const Duration(milliseconds: 1500), () {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  });
}

  // void _reorderGroups(int oldIndex, int newIndex) {
  //   setState(() {
  //     if (oldIndex < newIndex) newIndex -= 1;
  //     final item = _userGroups.removeAt(oldIndex);
  //     _userGroups.insert(newIndex, item);
  //   });
  // }

  void _toggleCloseCircleContact(Contact contact) {
    setState(() {
      if (_closeCircleContacts.contains(contact)) {
        _closeCircleContacts.remove(contact);
      } else {
        _closeCircleContacts.add(contact);
      }
    });
  }

  // New method for manual contact picking (replaces the old navigation)
  // Future<void> _pickContactsManually() async {
  //   final permissionOk = await fContacts.FlutterContacts.requestPermission();
  //   if (!permissionOk) {
  //     _showSettingsDialog('Contacts permission is required to pick contacts');
  //     return;
  //   }

  //   final contacts = await fContacts.FlutterContacts.getContacts(withProperties: true);

  //   final selectedContacts = await showDialog<List<fContacts.Contact>>(
  //     context: context,
  //     builder: (context) {
  //       final tempSelected = <fContacts.Contact>[];
  //       final searchController = TextEditingController();
  //       List<fContacts.Contact> filtered = List.of(contacts);

  //       void applyFilter(String query) {
  //         final q = query.trim().toLowerCase();
  //         filtered = q.isEmpty
  //             ? List.of(contacts)
  //             : contacts.where((c) {
  //                 final name = c.displayName.toLowerCase();
  //                 final phones = c.phones.map((p) => p.number.toLowerCase()).join(' ');
  //                 final emails = c.emails.map((e) => e.address.toLowerCase()).join(' ');
  //                 return name.contains(q) || phones.contains(q) || emails.contains(q);
  //               }).toList();
  //       }

  //       return StatefulBuilder(
  //         builder: (context, setStateDialog) {
  //           return AlertDialog(
  //             title: const Text('Select Contacts'),
  //             content: SizedBox(
  //               width: double.maxFinite,
  //               height: 520,
  //               child: Column(
  //                 children: [
  //                   // Search bar
  //                   TextField(
  //                     controller: searchController,
  //                     decoration: const InputDecoration(
  //                       prefixIcon: Icon(Icons.search),
  //                       hintText: 'Search by name, phone, or email',
  //                       border: OutlineInputBorder(),
  //                       isDense: true,
  //                     ),
  //                     onChanged: (val) {
  //                       setStateDialog(() {
  //                         applyFilter(val);
  //                       });
  //                     },
  //                   ),
  //                   const SizedBox(height: 12),
  //                   // Info + select all
  //                   Row(
  //                     children: [
  //                       Expanded(
  //                         child: Text(
  //                           'Showing ${filtered.length} of ${contacts.length}',
  //                           style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                         ),
  //                       ),
  //                       TextButton.icon(
  //                         onPressed: () {
  //                           setStateDialog(() {
  //                             // Select all filtered
  //                             for (final c in filtered) {
  //                               if (!tempSelected.contains(c)) {
  //                                 tempSelected.add(c);
  //                               }
  //                             }
  //                           });
  //                         },
  //                         icon: const Icon(Icons.select_all),
  //                         label: const Text('Select all'),
  //                       ),
  //                       TextButton(
  //                         onPressed: () {
  //                           setStateDialog(() {
  //                             // Clear only filtered from selection
  //                             tempSelected.removeWhere((c) => filtered.contains(c));
  //                           });
  //                         },
  //                         child: const Text('Clear'),
  //                       ),
  //                     ],
  //                   ),
  //                   const SizedBox(height: 8),
  //                   // List of contacts
  //                   Expanded(
  //                     child: filtered.isEmpty
  //                         ? const Center(child: Text('No contacts found'))
  //                         : ListView.separated(
  //                             itemCount: filtered.length,
  //                             separatorBuilder: (_, __) => const Divider(height: 1),
  //                             itemBuilder: (context, index) {
  //                               final contact = filtered[index];
  //                               final isSelected = tempSelected.contains(contact);
  //                               final primaryPhone = contact.phones.isNotEmpty
  //                                   ? contact.phones.first.number
  //                                   : '';
  //                               final primaryEmail = contact.emails.isNotEmpty
  //                                   ? contact.emails.first.address
  //                                   : '';
  //                               return CheckboxListTile(
  //                                 title: Text(contact.displayName),
  //                                 subtitle: Text(
  //                                   [primaryPhone, primaryEmail]
  //                                       .where((s) => s.isNotEmpty)
  //                                       .join(' • '),
  //                                 ),
  //                                 value: isSelected,
  //                                 onChanged: (checked) {
  //                                   setStateDialog(() {
  //                                     if (checked == true) {
  //                                       tempSelected.add(contact);
  //                                     } else {
  //                                       tempSelected.remove(contact);
  //                                     }
  //                                   });
  //                                 },
  //                                 controlAffinity: ListTileControlAffinity.leading,
  //                               );
  //                             },
  //                           ),
  //                   ),
  //                   // Selection count
  //                   Align(
  //                     alignment: Alignment.centerRight,
  //                     child: Text(
  //                       'Selected: ${tempSelected.length}',
  //                       style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context),
  //                 child: const Text('Cancel'),
  //               ),
  //               ElevatedButton.icon(
  //                 onPressed: () => Navigator.pop(context, tempSelected),
  //                 icon: const Icon(Icons.download),
  //                 label: const Text('Import Selected'),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );

  //   if (selectedContacts == null || selectedContacts.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('No contacts selected')),
  //     );
  //     return;
  //   }

  //   final authService = Provider.of<AuthService>(context, listen: false);
  //   final apiService = Provider.of<ApiService>(context, listen: false);
  //   final user = authService.currentUser;
  //   if (user == null) return;

  //   final syncService = ContactSyncService(apiService: apiService);

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   final result = await syncService.importFromContactPicker(
  //     pickedContacts: selectedContacts,
  //     onProgress: (processed, total) {
  //       // Progress callback if needed
  //     },
  //   );

  //   setState(() => _isLoading = false);

  //   if (result['success'] == true) {
  //     final updatedContacts = await apiService.getAllContacts();
  //   setState(() {
  //     _selectedContacts = updatedContacts;
  //   });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Successfully imported ${result['importedCount']} contacts!')),
  //     );
  //     // Update selected contacts count in UI
  //     setState(() {});
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to import contacts: ${result['message']}')),
  //     );
  //   }
  // }

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

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff3CB3E9),
                ),
              ),
              Text(
                _steps[_currentStep]['title'],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
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
    return Column(
      children: [
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
                                    title: Text('Error'),
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
                      backgroundColor: const Color.fromRGBO(45, 161, 175, 0.1),
                      child: _imageBytes == null 
                          ? const Icon(Icons.camera_alt, size: 40, color: Color(0xff3CB3E9))
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xff3CB3E9),
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
            const Text('Username *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Enter your username',
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
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
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please enter a username' : null,
              onChanged: onUserNameChange,
            ),
            const SizedBox(height: 20),
            
            // Phone Number with Country Code
            const Text('Phone Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 1),
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
                  ),
                )
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 9,
                    decoration: InputDecoration(
                      hintText: 'Phone number',
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter a phone number' : null,
                    onChanged: onPhoneChange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Bio
            const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell us a bit about yourself...',
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: onBioChange,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // [Rest of the methods remain exactly the same as previous implementation]
  // _buildGroupsStep, _buildContactsStep, _buildCloseCircleStep, _buildReviewStep
  // _buildSummaryItem, _reorderGroups, _toggleCloseCircleContact

Widget _buildGroupsStep() {
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('Customize Your Social Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('Drag to reorder groups by priority. Add, edit, or remove groups.', 
          style: TextStyle(fontSize: 14, color: Colors.grey)),
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
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
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
                      ? Border(bottom: BorderSide(color: Colors.grey.shade200))
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
    // List of conversational frequency options
    // final List<String> frequencyOptions = [
    //   'Every few days',
    //   'Weekly', 
    //   'Every 2 weeks',
    //   'Monthly',
    //   'Quarterly',
    //   'Twice a year',
    //   'Once a year'
    // ];

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
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: group.name,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                    isDense: true,
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
          const Text('Contact Frequency:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
         DropdownButtonFormField<String>(
            value: _getCurrentFrequencyChoice(group),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: FrequencyPeriodMapper.frequencyMapping.keys.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
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
          
          // Date Nudges Section
          const Text('Date Nudges:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          
          // Birthday Nudges Toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Send a nudge for birthdays',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
              Switch(
                value: group.birthdayNudgesEnabled,
                onChanged: (value) {
                  setState(() {
                    _userGroups[index] = group.copyWith(birthdayNudgesEnabled: value);
                  });
                },
              ),
            ],
          ),
          
          // Anniversary Nudges Toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Send a nudge for anniversaries',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
              Switch(
                value: group.anniversaryNudgesEnabled,
                onChanged: (value) {
                  setState(() {
                    _userGroups[index] = group.copyWith(anniversaryNudgesEnabled: value);
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Members section
          Text(
            '${group.memberIds.length} members',
            style: const TextStyle(
              color: Colors.grey,
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

  // Widget _buildPeriodButton(String period, bool isSelected, int groupIndex) {
  //   return Expanded(
  //     child: Container(
  //       margin: const EdgeInsets.symmetric(horizontal: 2),
  //       child: ElevatedButton(
  //         onPressed: () {
  //           setState(() {
  //             final range = {
  //               'Weekly': {'min': 1, 'max': 7, 'divisions': 6},
  //               'Monthly': {'min': 1, 'max': 7, 'divisions': 6},
  //               'Quarterly': {'min': 1, 'max': 7, 'divisions': 6},
  //               'Annually': {'min': 1, 'max': 7, 'divisions': 6},
  //             }[period]!;
              
  //             _userGroups[groupIndex] = _userGroups[groupIndex].copyWith(
  //               period: period,
  //               frequency: ((range['min']! + range['max']!) / 2).toInt(),
  //             );
  //           });
  //         },
  //         style: ElevatedButton.styleFrom(
  //           backgroundColor: isSelected ? const Color(0xff3CB3E9) : Colors.grey[200],
  //           foregroundColor: isSelected ? Colors.white : Colors.black,
  //           padding: const EdgeInsets.symmetric(vertical: 8),
  //         ),
  //         child: Text(period, style: const TextStyle(fontSize: 12)),
  //       ),
  //     ),
  //   );
  // }

  void _addNewGroup() {
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
    ));
  });
}

  void _deleteGroup(int index) {
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

  // String _getFrequencyLabel(String period, double frequency) {
  //   switch (period) {
  //     case 'Weekly':
  //       return '${frequency.toInt()} times per week';
  //     case 'Monthly':
  //       return '${frequency.toInt()} times per month';
  //     case 'Quarterly':
  //       return '${frequency.toInt()} times per quarter';
  //     case 'Annually':
  //       return '${frequency.toInt()} times per year';
  //     default:
  //       return '${frequency.toInt()} times';
  //   }
  // }

  Widget _buildContactsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text('Add Your Contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Import your contacts or add them manually. You can skip this and do it later.', 
            style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          
          // Import Options - Fixed layout
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5, right: 5, bottom: 20, top: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.import_contacts, size: 60, color: Color(0xff3CB3E9)),
                        const SizedBox(height: 16),
                        const Text('Quick Import', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Import your existing contacts', 
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ImportContactsScreen()),
                            );
                            
                            if (result != null && result is List<Contact>) {
                              setState(() {
                                _selectedContacts = result;
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
                  child: Padding(
                     padding: const EdgeInsets.only(left: 5, right: 5, bottom: 20, top: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Add Manually', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Select specific contacts to import', 
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 20),
                        OutlinedButton(
                          onPressed: () {
                            FocusScope.of(context).unfocus();
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

  Widget _buildCloseCircleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('Identify Your Close Circle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          // Explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(45, 161, 175, 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info, color: Color(0xff3CB3E9)),
                  SizedBox(width: 8),
                  Text('What is a Close Circle?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff3CB3E9))),
                ]),
                SizedBox(height: 8),
                Text(
                  'Your Close Circle is for people you naturally connect with often — those relationships don\'t need reminders. NUDGE will include them in your weekly reflection so you can note how things are going.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Contact Selection
          if (_selectedContacts.isNotEmpty) ...[
            const Text('Select your Close Circle members:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            
            ..._selectedContacts.map((contact) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: contact.phoneNumber.isNotEmpty ? Text(contact.phoneNumber) : null,
                secondary: CircleAvatar(
                  backgroundColor: const Color(0xff3CB3E9),
                  child: Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                ),
                value: _closeCircleContacts.contains(contact),
                onChanged: (bool? value) => _toggleCloseCircleContact(contact),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            )).toList(),
          ] else ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No Contacts Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('You haven\'t added any contacts yet. You can add them later from the dashboard.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
                  color: const Color.fromRGBO(45, 161, 175, 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 50, color: Color(0xff3CB3E9)),
              ),
              const SizedBox(height: 20),
              const Text('You\'re all set! 🎉', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'We\'ve created your groups and scheduled your first nudges. You\'ll start seeing reminders soon — and get your first Weekly Digest this Sunday!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
            ]),
          ),
          
          const SizedBox(height: 40),
          const Text('Your Nudge Setup:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    return ListTile(
      leading: Icon(icon, color: const Color(0xff3CB3E9)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
    );
  }

  Future<void> _scheduleNudgesForImportedContacts() async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final nudgeService = NudgeService();
  final user = authService.currentUser;
  
  if (user == null || _selectedContacts.isEmpty) return;

  try {
    int scheduledCount = 0;
    
    for (final contact in _selectedContacts) {
      // Find the group for this contact
      SocialGroup? group = _userGroups.firstWhere(
        (g) => contact.socialGroups.contains(g.id),
        orElse: () => _userGroups.first, // Default to first group
      );
      
      final success = await nudgeService.scheduleNudgeForContact(
        contact,
        user.uid,
        period: group.period,
        frequency: group.frequency,
      );
      
      if (success) scheduledCount++;
      
      // Small delay to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (scheduledCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scheduled nudges for $scheduledCount contacts')),
      );
    }
  } catch (e) {
    print('Error scheduling nudges: $e');
    // Don't show error to user as this is background process
  }
}

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
    onTap: () => FocusScope.of(context).unfocus(),
    child: Scaffold(
      appBar: AppBar(
        title: GradientText( text: 'NUDGE', style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF5CDEE5), // #5CDEE5
                  Color(0xFF2D85F6), // #2D85F6
                  Color(0xFF7A4BFF), // #7A4BFF
                ], stops: [0.0, 0.6, 1.0], begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        // Text('NUDGE', style: AppTextStyles.title2.copyWith(color: const Color(0xff3CB3E9), fontFamily: 'RobotoMono')),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false, // Remove back button
        elevation: 0,
      ),
      body: Column(children: [
        if (!_isCropping) _buildStepIndicator(),
        Expanded(child: _buildCurrentStep()),
        if (!_isCropping) Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: Row(children: [
            if (_currentStep > 0) Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff3CB3E9),
                  side: const BorderSide(color: Color(0xff3CB3E9)),
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
                onPressed: _isStepValid(_currentStep) ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3CB3E9),
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
    ));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Contacts'),
        actions: [
          // Selection info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_selectedContacts.length} selected',
                style: const TextStyle(fontSize: 16),
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
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name, phone, or email...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
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
                  style: const TextStyle(color: Colors.grey),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _selectAll,
                      child: const Text('Select All'),
                    ),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Clear'),
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
                ? const Center(
                    child: Text(
                      'No contacts found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
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
                      
                      // Extract important dates
                      // final birthday = contact.events.firstWhere(
                      //   (e) => e.label.name.toLowerCase().contains('birthday'),
                      //   orElse: () => fContacts.Event('', ''),
                      // );
                      
                      // final anniversary = contact.events.firstWhere(
                      //   (e) => e.label.name.toLowerCase().contains('anniversary'),
                      //   orElse: () => fContacts.Event('', ''),
                      // );

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: CheckboxListTile(
                          title: Text(
                            contact.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (primaryPhone.isNotEmpty) Text(primaryPhone),
                              if (primaryEmail.isNotEmpty) Text(primaryEmail),
                              // if (birthday.date != null) 
                              //   Text('🎂 Birthday: ${_formatDate(birthday.date!)}'),
                              // if (anniversary.date != null)
                              //   Text('💑 Anniversary: ${_formatDate(anniversary.date!)}'),
                            ],
                          ),
                          secondary: CircleAvatar(
                            backgroundColor: const Color(0xff3CB3E9),
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
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
                  foregroundColor: const Color(0xff3CB3E9),
                  side: const BorderSide(color: Color(0xff3CB3E9)),
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
                  backgroundColor: const Color(0xff3CB3E9),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assign to Group',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select which group these contacts belong to:',
              style: TextStyle(color: Colors.grey),
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
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isSelected ? const Color.fromRGBO(60, 179, 233, 0.1) : null,
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
                          color: isSelected ? const Color(0xff3CB3E9) : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '${group.frequency} times ${group.period.toLowerCase()}',
                        style: TextStyle(
                          color: isSelected ? const Color(0xff3CB3E9) : Colors.grey,
                        ),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: Color(0xff3CB3E9))
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
                      foregroundColor: const Color(0xff3CB3E9),
                      side: const BorderSide(color: Color(0xff3CB3E9)),
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
                      backgroundColor: const Color(0xff3CB3E9),
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
    );
  }
}