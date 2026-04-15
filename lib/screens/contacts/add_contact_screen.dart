// lib/screens/contacts/add_contact_screen.dart
import 'dart:math';
import 'dart:typed_data';

// import 'package:another_flushbar/flushbar.dart';
import 'package:confetti/confetti.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nudge/main.dart';
import 'package:nudge/providers/feedback_provider.dart';
import 'package:nudge/screens/contacts/contact_detail_screen.dart';
// import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/message_service.dart';
// import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:country_code_picker/country_code_picker.dart';
// import 'package:nudge/widgets/hi_five_animation.dart';
// import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
// import '../../services/database_service.dart';
import '../../services/auth_service.dart';
// import '../../services/tagging_service.dart';
import '../../models/contact.dart';
import '../../models/social_group.dart';
import '../../widgets/connection_type_chip.dart';
import 'dart:io';
// import 'package:image_picker/image_picker.dart';
// import '../../services/storage_service.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
// import '../../theme/app_theme.dart';

class AddContactScreen extends StatefulWidget {
  final String? groupName;
  final String? groupPeriod;
  final int? groupFrequency;
  final bool isOnboarding;
  final List<SocialGroup>? groups;
  
  AddContactScreen({super.key, this.groupName, this.groupPeriod, this.groupFrequency, this.isOnboarding = false, this.groups});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _socialGroupsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  late FeedbackFloatingButtonController _fabController;

  File? _selectedImage;
  String _imageUrl = '';
  // final StorageService _storageService = StorageService();
  
  String _connectionType = 'Friend';
  // String _frequency = 'Monthly';
  bool _isVIP = false;
  int _priority = 3;
  List<String> _tags = [];
  List<String> _tagSuggestions = [];
  List<SocialGroup> _userGroups = [];
  DateTime? _birthday;
  DateTime? _anniversary;
  DateTime? _workAnniversary;
  bool _isCropping = false;
  final _cropController = CropController();
  Uint8List? _imageBytes;
  bool saving = false;
  CountryCode _selectedCountry = CountryCode(dialCode: '+971', code: 'AE');
  // bool _showCelebration = false;
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3)
  );
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    // Load tag suggestions based on existing contacts
    //  if (widget.groupName != null) {
    //   _connectionType = widget.groupName!;
    // }
    
    // _loadTagSuggestions();
    _loadUserGroups();
    _fabController = FeedbackFloatingButtonController();
    
  }

  void _loadUserGroups() async {
    if (widget.isOnboarding && widget.groups != null && widget.groups!.isNotEmpty) {
      setState(() {
        _userGroups = widget.groups!;
        if (_userGroups.isNotEmpty) {
          _connectionType = _userGroups.first.name;
        }
      });
      return;
    }
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final groups = await apiService.getGroupsStream().first;
        
        if (groups.isEmpty && widget.isOnboarding){
          var newGroups = _createDefaultGroups();
          setState(() {
            _userGroups = newGroups;
          });
          return;
        }
        setState(() {
          _userGroups = groups;
          if (_userGroups.isNotEmpty) {
            _connectionType = _userGroups.first.name;
          }
        });
      }
    } catch (e) {
      //print('Error loading user groups: $e');
    }
  }

    List<SocialGroup> _createDefaultGroups() {
    return [
      SocialGroup(
        id: 'family',
        name: 'Family',
        description: '',
        period: 'Monthly',
        frequency: 4,
        memberIds: [],
        memberCount: 0,
        lastInteraction: DateTime.now(),
        colorCode: '#4FC3F7',
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 0
      ),
      SocialGroup(
        id: 'friend',
        name: 'Friend',
        description: '',
        period: 'Weekly',
        frequency: 2,
        memberIds: [],
        memberCount: 0,
        lastInteraction: DateTime.now(),
        colorCode: '#FF6F61',
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 1
      ),
      SocialGroup(
        id: 'colleague',
        name: 'Colleague',
        description: '',
        period: 'Monthly',
        frequency: 2,
        memberIds: [],
        memberCount: 0,
        lastInteraction: DateTime.now(),
        colorCode: '#81C784',
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 2
      ),
      SocialGroup(
        id: 'client',
        name: 'Client',
        description: '',
        period: 'Quarterly',
        frequency: 1,
        memberIds: [],
        memberCount: 0,
        lastInteraction: DateTime.now(),
        colorCode: '#FFC107',
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 3
      ),
      SocialGroup(
        id: 'mentor',
        name: 'Mentor',
        description: '',
        period: 'Annually',
        frequency: 2,
        memberIds: [],
        memberCount: 0,
        lastInteraction: DateTime.now(),
        colorCode: '#607D8B',
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
        orderIndex: 4
      ),
    ];
  }


  // void _loadTagSuggestions() async {
  //   final authService = Provider.of<AuthService>(context, listen: false);
  //   final user = authService.currentUser;
  //   if (user == null) return;

  //   final apiService = ApiService();
  //   final contacts = await apiService.getContactsStream() as List<dynamic>;
    
  //   // Get unique tags from all contacts
  //   Set<String> allTags = {};
  //   for (var contact in contacts) {
  //     allTags.addAll(contact.tags);
  //   }
    
  //   setState(() {
  //     _tagSuggestions = allTags.toList();
  //   });
  // }

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

  int getRandomIndex(String seed) {
  if (seed.isEmpty) return 1;
  var hash = 0;
  for (var i = 0; i < seed.length; i++) {
    hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return (hash.abs() % 6) + 1;
}

  // Add the crop image method
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

  Future<Map<String, dynamic>> matchSchedule(String groupName, List<SocialGroup> groups) async {
    //print('Matching schedule for group: $groupName');
    
    // If we have groups passed from onboarding, use them
    final List<SocialGroup> targetGroups = widget.isOnboarding && widget.groups != null 
        ? widget.groups! 
        : groups;
    
    try {
      SocialGroup myGroup = targetGroups.firstWhere((group) => group.name == groupName);
      Map<String, dynamic> schedule = {'period': myGroup.period, 'frequency': myGroup.frequency};
      //print('Found schedule: $schedule');
      return schedule;
    } catch (e) {
      //print('Group not found, using default schedule: $e');
      // Return a default schedule if group not found
      return {'period': 'Monthly', 'frequency': 2};
    }
  }

   void _deleteImage() {
    setState(() {
      _selectedImage = null;
      _imageUrl = '';
    });
  }

  Future<void> _selectDate(BuildContext context, {
    bool isBirthday = false,
    bool isAnniversary = false,
    bool isWorkAnniversary = false,
  }) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: themeProvider.isDarkMode
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.lightPrimary,
                    onPrimary: Colors.white,
                    surface: AppColors.darkSurface,
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.lightPrimary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isBirthday) {
          _birthday = picked;
        } else if (isAnniversary) {
          _anniversary = picked;
        } else if (isWorkAnniversary) {
          _workAnniversary = picked;
        }
      });
    }
  }

  Widget _buildCropScreen() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    var size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: size.height,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
      children: [
        const SizedBox(height: 100),
        Text(
          'CROP CONTACT PICTURE',
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600, textBaseline: null,
            decorationColor: Colors.black, decorationThickness: 0
          ),
        ),
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
                          setState(() {
                            // Store the cropped image for the contact
                            _imageBytes = croppedImage;
                            _isCropping = false;
                          });
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
                    baseColor: themeProvider.isDarkMode ? AppColors.darkSurface : Colors.white,
                    maskColor: themeProvider.isDarkMode ? AppColors.darkSurface.withAlpha(150) : Colors.white.withAlpha(100),
                    cornerDotBuilder: (size, edgeAlignment) => DotControl(color: themeProvider.isDarkMode ? AppColors.lightPrimary : Theme.of(context).colorScheme.secondary),
                  )
                : Center(child: CircularProgressIndicator(color: themeProvider.isDarkMode ? AppColors.lightPrimary : null)),
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
    ));
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

  // Add this method inside _AddContactScreenState
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

  // Add this widget method inside _AddContactScreenState
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
              style: TextStyle(
                fontSize: 12,
                color: themeProvider.isDarkMode ? Color.fromARGB(255, 192, 165, 226): AppColors.lightPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

    void _showValidationAlert(ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 8),
            Text(
              'Cannot Save Contact',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please fix the following issues:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            
            // Name validation
            if (_nameController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.close, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Name is required',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Phone validation
            if (_phoneController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.close, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Phone number is required',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              )
            else if (!_isValidPhoneNumber(_phoneController.text))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.close, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Phone number must be exactly 9 digits',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Connection type validation
            if (_userGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.close, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No connection types available. Please create a group first.',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              )
            else if (_connectionType.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.close, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please select a connection type',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.lightPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'GOT IT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  navigate() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final apiService = Provider.of<ApiService>(context);
    final user = authService.currentUser;
    final feedbackProvider = Provider.of<FeedbackProvider>(context);
    // var size = MediaQuery.of(context).size;
    
    if (_isCropping) {
      return _buildCropScreen();
    }
    
    return StreamProvider<List<SocialGroup>>.value(
        value: widget.isOnboarding && widget.groups != null
      ? Stream.value(widget.groups!) // Use passed groups if onboarding
      : apiService.getGroupsStream(), // Otherwise use API stream
        initialData: const [],
        child: Consumer<List<SocialGroup>>(
          builder: (context, groups, child) {
            return GestureDetector(
              onTap: _dismissKeyboard,
              child: Scaffold(
                floatingActionButton: Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: FeedbackFloatingButton(
                    controller: _fabController,
                  ),
                ),
                body: Stack(
                  children: [
                    Scaffold(
                  appBar: AppBar(
                  title: Text('Add Contact', style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800)),
                  centerTitle: true,
                  iconTheme: IconThemeData(color: themeProvider.isDarkMode?const Color.fromARGB(255, 192, 165, 226):AppColors.lightPrimary),
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
                        Center(
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.01),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.transparent,
                                    backgroundImage: _imageBytes != null
                                        ? MemoryImage(_imageBytes!)
                                        : (_imageUrl.isNotEmpty
                                            ? NetworkImage(_imageUrl)
                                            : AssetImage('assets/contact-icons/${getRandomIndex(_nameController.text)}.png') as ImageProvider),
                                    child: _imageBytes == null && _imageUrl.isEmpty
                                        ? Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              image: DecorationImage(
                                                image: AssetImage('assets/contact-icons/${getRandomIndex(_nameController.text)}.png'),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            child: Center(
                                              child: _nameController.text.isNotEmpty 
                                              ?Text(
                                                 _nameController.text[0].toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 40,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ):Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.onSurface),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              if (_selectedImage != null || _imageUrl.isNotEmpty)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Color.fromARGB(255, 206, 37, 85),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.onSurface, size: 20),
                                      onPressed: _deleteImage,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Text(
                        //   'Add details below',
                        //   style: TextStyle(
                        //     fontSize: 16,
                        //     color: Theme.of(context).colorScheme.onSurfaceVariant,
                        //   ),
                        // ),
                        // const SizedBox(height: 30),
                        
                        // Name field
                        Text(
                          'NAME *',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Enter full name',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
                              borderRadius: BorderRadius.circular(14)
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
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
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Connection Type - Now dynamically loaded from user groups
                        Text(
                          'CONNECTION TYPE *',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                        ),
                        const SizedBox(height: 8),
                        _userGroups.isEmpty
                            ? Text('No groups available. Create groups first.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: GoogleFonts.beVietnamPro().fontFamily))
                            : Wrap(
                                spacing: 8,
                                runSpacing: 10,
                                children: _userGroups.map((group) {
                                  return ConnectionTypeChip(
                                    label: group.name,
                                    isSelected: _connectionType == group.name,
                                    onSelected: (selected) {
                                      if (selected) setState(() => _connectionType = group.name);
                                    },
                                  );
                                }).toList(),
                              ),
                        
                        const SizedBox(height: 20),
                        
                        // VIP and Priority
                        Row(
                          children: [
                            Theme(
                              data: ThemeData(
                                checkboxTheme: CheckboxThemeData(
                                  fillColor: MaterialStateProperty.resolveWith<Color?>(
                                    (Set<MaterialState> states) {
                                      if (states.contains(MaterialState.selected)) {
                                        return AppColors.lightPrimary;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              child: Checkbox(
                                value: _isVIP,
                                onChanged: (value) {
                                  setState(() => _isVIP = value ?? false);
                                },
                              ),
                            ),
                            Text('Favourites', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily)),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Profession
                        Text(
                          'PROFESSION',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _professionController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                          decoration: InputDecoration(
                            hintText: 'Enter profession',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline, fontFamily: GoogleFonts.beVietnamPro().fontFamily),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
                              borderRadius: BorderRadius.circular(14)
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
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
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Important Dates Section
                        Text(
                          'IMPORTANT DATES',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Birthday
                        ListTile(
                          leading: Icon(Icons.cake, color: Theme.of(context).colorScheme.onSurface),
                          title: Text(
                            _birthday != null
                                ? 'Birthday: ${DateFormat('MMM d, y').format(_birthday!)}'
                                : 'Add Birthday',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onSurface),
                            onPressed: () => _selectDate(context, isBirthday: true),
                          ),
                        ),
                        
                        // Anniversary
                        ListTile(
                          leading: Icon(Icons.favorite, color: Theme.of(context).colorScheme.onSurface),
                          title: Text(
                            _anniversary != null
                                ? 'Anniversary: ${DateFormat('MMM d, y').format(_anniversary!)}'
                                : 'Add Anniversary',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onSurface),
                            onPressed: () => _selectDate(context, isAnniversary: true),
                          ),
                        ),
                        
                        // Work Anniversary
                        ListTile(
                          leading: Icon(Icons.work, color: Theme.of(context).colorScheme.onSurface),
                          title: Text(
                            _workAnniversary != null
                                ? 'Work Anniversary: ${DateFormat('MMM d, y').format(_workAnniversary!)}'
                                : 'Add Work Anniversary',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onSurface),
                            onPressed: () => _selectDate(context, isWorkAnniversary: true),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Tags
                        Text(
                          'SOCIAL GROUPS',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        
                        // Tag suggestions
                        if (_tagSuggestions.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            children: _tagSuggestions.map((tag) {
                              return FilterChip(
                                label: Text(tag, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                selected: _tags.contains(tag),
                                selectedColor: AppColors.lightPrimary.withOpacity(0.3),
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _tags.add(tag);
                                    } else {
                                      _tags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                        
                        // // Add new tag
                        // Row(
                        //   children: [
                        //     Expanded(
                        //       child: TextFormField(
                        //         controller: _tagsController,
                        //         style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        //         decoration: InputDecoration(
                        //           hintText: 'Add new Social Group',
                        //           hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                        //           enabledBorder: OutlineInputBorder(
                        //             borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
                        //             borderRadius: BorderRadius.circular(14)
                        //           ),
                        //           focusedBorder: OutlineInputBorder(
                        //             borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
                        //             borderRadius: BorderRadius.circular(14)
                        //           ),
                        //           errorBorder: OutlineInputBorder(
                        //             borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 1),
                        //             borderRadius: BorderRadius.circular(14)
                        //           ),
                        //           focusedErrorBorder: OutlineInputBorder(
                        //             borderSide: BorderSide(color: Color.fromARGB(255, 206, 37, 85), width: 2),
                        //             borderRadius: BorderRadius.circular(14)
                        //           ),
                        //           filled: true,
                        //           fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                        //         ),
                        //       ),
                        //     ),
                        //     IconButton(
                        //       icon: Icon(Icons.add, color: AppColors.lightPrimary),
                        //       onPressed: () {
                        //         if (_tagsController.text.isNotEmpty) {
                        //           setState(() {
                        //             _tags.add(_tagsController.text);
                        //             _tagsController.clear();
                        //           });
                        //         }
                        //       },
                        //     ),
                        //   ],
                        // ),
                        
                        // // Display selected tags
                        // Wrap(
                        //   spacing: 8,
                        //   children: _tags.map((tag) {
                        //     return Chip(
                        //       label: Text(tag, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        //       backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                        //       deleteIconColor: Color.fromARGB(255, 206, 37, 85),
                        //       onDeleted: () {
                        //         setState(() => _tags.remove(tag));
                        //       },
                        //     );
                        //   }).toList(),
                        // ),
                        
                        const SizedBox(height: 20),
                        
                        // Phone Number
                       // Phone Number
                        Text(
                          'PHONE NUMBER',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
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
                                dialogBackgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                keyboardType: TextInputType.phone,
                                maxLength: 12,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Enter phone number',
                                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                                  counterText: '',
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
                                    borderRadius: BorderRadius.circular(14)
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
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
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
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
                                  setState(() {
                                    // Trigger rebuild for validation message
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        _buildPhoneValidationMessage(), // Add this line
                        const SizedBox(height: 20),
                        
                        // Email
                        Text(
                          'EMAIL',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter email address',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
                              borderRadius: BorderRadius.circular(14)
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
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
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Notes
                        Text(
                          'NOTES',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add any notes about this contact',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
                              borderRadius: BorderRadius.circular(14)
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
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
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () async {
                              //print('stage0');
                              // First, dismiss keyboard
                              _dismissKeyboard();
                              
                              // Check if form is valid
                              if (!_formKey.currentState!.validate()) {
                                _showValidationAlert(themeProvider);
                                return;
                              }
                              setState(() {
                                saving = true;
                              });
                              if (_formKey.currentState!.validate() && user != null) {
                                // Upload image if selected
                                if (_imageBytes != null) {
                                  try {
                                    _imageUrl = await uploadImageToFirebase(_imageBytes!, 'new_contact_${DateTime.now().millisecondsSinceEpoch}');
                                  } catch (e) {
                                    // Flushbar(
                                    //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
                                    //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                                    //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                                    //   messageText: Center(
                                    //       child: Text('Failed to upload image: $e', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
                                    //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
                                    // ).show(context);

                                     TopMessageService().showMessage(
                                        context: context,
                                        message: 'Failed to upload image: $e!}',
                                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                                        icon: Icons.error,
                                      );
                                    return;
                                  }
                                }

                                // Use group settings if provided, otherwise use default matching
                                String period;
                                int frequency;
                                //print('stage1');
                                
                                if (widget.groupPeriod != null && widget.groupFrequency != null) {
                                  period = widget.groupPeriod!;
                                  frequency = widget.groupFrequency!;
                                } else {
                                  final List<SocialGroup> targetGroups = widget.isOnboarding && widget.groups != null 
                                  ? widget.groups! 
                                  : groups;
                                  Map<String, dynamic> schedule = await matchSchedule(_connectionType, targetGroups);
                                  period = schedule['period'];
                                  frequency = schedule['frequency'];
                                }
                                //print('stage2');
                                
                                final newContact = Contact(
                                  id: generateRandomId(16) + _nameController.text.substring(0, 4),
                                  name: _nameController.text,
                                  connectionType: _connectionType,
                                  frequency: frequency,
                                  period: period,
                                  socialGroups: _socialGroupsController.text
                                      .split(' ')
                                      .where((group) => group.startsWith('#'))
                                      .map((group) => group.substring(1))
                                      .toList(),
                                  phoneNumber: _selectedCountry.dialCode! + _phoneController.text.trim(),
                                  email: _emailController.text,
                                  notes: _notesController.text,
                                  imageUrl: _imageUrl,
                                  lastContacted: DateTime.now(),
                                  isVIP: _isVIP,
                                  priority: _priority,
                                  tags: _tags,
                                  interactionHistory: {},
                                  profession: _professionController.text.isEmpty ? null : _professionController.text,
                                  birthday: _birthday,
                                  anniversary: _anniversary,
                                  workAnniversary: _workAnniversary,
                                );
                                
                                // Save to Firestore
                                await apiService.addContact(newContact);
                                //print('stage3');
                                
                                // Automatically schedule nudge based on connection category
                                try {
                                  // final nudgeService = NudgeService();
                                  // await nudgeService.scheduleNudgeForContact(
                                  //   newContact, 
                                  //   user.uid,
                                  //   period: period,
                                  //   frequency: frequency,
                                  // );
                                  apiService.scheduleNudgesForContacts(contactIds: [newContact.id]);
                                  apiService.scheduleEventNotifications([newContact]);
                                  //print('Automatic nudge scheduled for ${newContact.name}');
                                } catch (e) {
                                  //print('Error scheduling automatic nudge: $e');
                                  // Don't show error to user - nudge scheduling is secondary
                                }
                               
                                if (!widget.isOnboarding){
                                //   Flushbar(
                                //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
                                //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
                                //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
                                //   messageText: Center(
                                //       child: Text('Successfully Created Contact', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
                                //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
                                // ).show(context);
                                 TopMessageService().showMessage(
                                    context: context,
                                    message: 'Successfully Created Contact}',
                                    backgroundColor: AppColors.success,
                                    icon: Icons.check,
                                  );
                                }
                                // Show success animation
                                setState(() {
                                  // _showConfetti = true;
                                  saving = false;
                                });

                                // Start confetti
                                // _confettiController.play();

                                // Close after animation
                               if (widget.isOnboarding) {
                                  if (Navigator.canPop(context)) {
                                      Navigator.pop(context, newContact);
                                    }
                                } else {
                                  // Navigate back one page (to contacts list or previous screen)
                                  
                                  // Navigator.pop(navigatorKey.currentContext!);

                                  // Then navigate to contact details with showConfetti flag
                                  Navigator.push(
                                    navigatorKey.currentContext!,
                                    MaterialPageRoute(
                                      builder: (context) => ContactDetailScreen(
                                        contact: newContact,
                                        navigate: navigate,
                                        showConfetti: true, // We'll add this parameter
                                      ),
                                    ),
                                  );
                                }
                                
                                setState(() {
                                  saving = false;
                                });

                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: saving?const Color.fromARGB(255, 119, 119, 119):AppColors.lightPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              saving?'SAVING CONTACT...':'SAVE CONTACT',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
                if (feedbackProvider.isFabMenuOpen)
                  GestureDetector(
                    onTap: () {
                      // Optional: Close the menu when tapping the overlay
                      // You'll need to access the FeedbackFloatingButton's state
                      // This is handled automatically if the button listens to provider changes
                       _fabController.closeMenu();
                    },
                    child: Container(
                      color: Colors.transparent,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),
                 if (_showConfetti)
                    Positioned.fill(
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        numberOfParticles: 20,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                        colors: [
                          AppColors.success,
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(context).colorScheme.tertiary,
                          AppColors.warning,
                          Theme.of(context).colorScheme.primary,
                          AppColors.lightPrimary, // Your app's primary color
                        ],
                        // createParticlePath: _drawStar, // Optional: for star-shaped confetti
                      ),
                    ),
                ])
              ));
    }));
  }
  
  @override
  void dispose() {
     _confettiController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _socialGroupsController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    _professionController.dispose();
    _fabController = FeedbackFloatingButtonController();
    super.dispose();
  }
}