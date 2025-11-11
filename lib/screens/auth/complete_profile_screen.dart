// complete_profile_screen.dart - Updated with crop_your_image
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/social_group.dart';
// import 'package:nudge/models/user.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'dart:io';
// import 'dart:ui' as ui;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../contacts/import_contacts_screen.dart';
import '../dashboard/dashboard_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
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
      SocialGroup(id: 'family', name: 'Family', period: 'Monthly', frequency: 4, colorCode: '#4FC3F7', description: '', memberCount: 0, memberIds: [], lastInteraction: DateTime.now(), dateNudgesEnabled: false),
      SocialGroup(id: 'friend', name: 'Friend', period: 'Weekly', frequency: 2, colorCode: '#FF6F61', description: '', memberCount: 0, memberIds: [], lastInteraction: DateTime.now(), dateNudgesEnabled: false),
      SocialGroup(id: 'colleagues', name: 'Colleagues', period: 'Monthly', frequency: 2, colorCode: '#81C784', description: '', memberCount: 0, memberIds: [], lastInteraction: DateTime.now(), dateNudgesEnabled: false),
      SocialGroup(id: 'clients', name: 'Clients', period: 'Quarterly', frequency: 1, colorCode: '#FFC107', description: '', memberCount: 0, memberIds: [], lastInteraction: DateTime.now(), dateNudgesEnabled: false),
      SocialGroup(id: 'mentors', name: 'Mentors', period: 'Annually', frequency: 2, colorCode: '#607D8B', description: '', memberCount: 0, memberIds: [], lastInteraction: DateTime.now(), dateNudgesEnabled: false),
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
        return _selectedContacts.isNotEmpty;
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

        // Navigate to dashboard
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _reorderGroups(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _userGroups.removeAt(oldIndex);
      _userGroups.insert(newIndex, item);
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
                        color: const Color.fromRGBO(45, 161, 175, 1),
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
                  color: Color.fromRGBO(45, 161, 175, 1),
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
                    backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
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
                          ? const Icon(Icons.camera_alt, size: 40, color: Color.fromRGBO(45, 161, 175, 1))
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
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
                Container(
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
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
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
          const Text('Organize Your Social Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Drag and drop to reorder your groups by priority.', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 30),
          
          // Reorderable groups list
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
                  child: ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(group.colorCode.replaceAll('#', '0xFF'))),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.group, color: Colors.white, size: 20),
                    ),
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${group.frequency} times ${group.period.toLowerCase()}'),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  ),
                );
              },
              onReorder: _reorderGroups,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildContactsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('Add Your Contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Import your contacts or add them manually.', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 40),
          
          // Import Options
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.import_contacts, size: 60, color: Color.fromRGBO(45, 161, 175, 1)),
                  const SizedBox(height: 16),
                  const Text('Quick Import', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Import your existing contacts with smart filtering', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ImportContactsScreen()),
                      ).then((result) {
                        if (result != null && result is List<Contact>) {
                          setState(() => _selectedContacts = result);
                          _nextStep();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Import Contacts', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Manual Add Option
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.person_add, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Add Manually', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Add contacts one by one', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add_contact').then((_) => _nextStep());
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color.fromRGBO(45, 161, 175, 1),
                      side: const BorderSide(color: Color.fromRGBO(45, 161, 175, 1)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Add Contact Manually'),
                  ),
                ],
              ),
            ),
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
                  Icon(Icons.info, color: Color.fromRGBO(45, 161, 175, 1)),
                  SizedBox(width: 8),
                  Text('What is a Close Circle?', style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromRGBO(45, 161, 175, 1))),
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
                  backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
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
                  Text('You haven\'t added any contacts yet. Go back to import or add contacts first.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
                child: const Icon(Icons.check, size: 50, color: Color.fromRGBO(45, 161, 175, 1)),
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
          _buildSummaryItem(Icons.contacts, '${_selectedContacts.length} Contacts', 'Ready to nurture'),
          _buildSummaryItem(Icons.star, 'Close Circle', '${_closeCircleContacts.length} important relationships'),
          _buildSummaryItem(Icons.notifications, 'Weekly Digest', 'Starting this Sunday'),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: const Color.fromRGBO(45, 161, 175, 1)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NUDGE', style: AppTextStyles.title3.copyWith(color: const Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono')),
        centerTitle: true,
        backgroundColor: Colors.white,
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
                  foregroundColor: const Color.fromRGBO(45, 161, 175, 1),
                  side: const BorderSide(color: Color.fromRGBO(45, 161, 175, 1)),
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
                  backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
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

// Add this import at the top if not already present
// import 'dart:typed_data';