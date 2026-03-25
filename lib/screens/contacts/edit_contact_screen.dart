// lib/screens/contacts/edit_contact_screen.dart
import 'dart:typed_data';

// import 'package:another_flushbar/flushbar.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nudge/providers/feedback_provider.dart';
import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
// import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/contact.dart';
import '../../models/social_group.dart';
import '../../theme/text_styles.dart';
import '../../widgets/connection_type_chip.dart';
import 'dart:io';
import '../../services/storage_service.dart';
import '../../providers/theme_provider.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../theme/app_theme.dart';
import 'package:phone_number/phone_number.dart';

class EditContactScreen extends StatefulWidget {
  final String contactId;
  final Map<String, dynamic>? importedContact;
  final bool isImported;

  const EditContactScreen({
    super.key,
    required this.contactId,
    this.isImported = false,
    this.importedContact,
  });

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  late TextEditingController _socialGroupsController;
  late TextEditingController _professionController;
  final PhoneNumberUtil _phoneNumberUtil = PhoneNumberUtil();

  String _connectionType = 'Friend';
  bool _isVIP = false;
  int _priority = 3;
  List<String> _tags = [];
  DateTime? _birthday;
  DateTime? _anniversary;
  DateTime? _workAnniversary;

  File? _selectedImage;
  String _imageUrl = '';
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  Contact? _originalContact;
  List<SocialGroup> _userGroups = [];
  bool _isCropping = false;
  bool saving = false;
  final _cropController = CropController();
  Uint8List? _imageBytes;
  CountryCode _selectedCountry = CountryCode(dialCode: '+971', code: 'AE');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _notesController = TextEditingController();
    _socialGroupsController = TextEditingController();
    _professionController = TextEditingController();

    _loadContactData();
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final groups = await apiService.getGroupsStream().first;
        
        setState(() {
          _userGroups = groups;
        });
      }
    } catch (e) {
      print('Error loading user groups: $e');
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  //   void _initializeCountryCodeFromPhone(String phoneNumber) {
  //   if (phoneNumber.isNotEmpty) {
  //     // Check if number starts with country code
  //     if (phoneNumber.startsWith('+')) {
  //       // Find country code in the string
  //       final match = RegExp(r'^\+\d{1,4}').firstMatch(phoneNumber);
  //       if (match != null) {
  //         final dialCode = match.group(0)!;
  //         // Try to find the country code
  //         if (dialCode == '+971') {
  //           setState(() => _selectedCountry = CountryCode(dialCode: '+971', code: 'AE'));
  //           _phoneController.text = phoneNumber.substring(dialCode.length);
  //           return;
  //         } else if (dialCode == '+1') {
  //           setState(() => _selectedCountry = CountryCode(dialCode: '+1', code: 'US'));
  //           _phoneController.text = phoneNumber.substring(dialCode.length);
  //           return;
  //         } else if (dialCode == '+44') {
  //           setState(() => _selectedCountry = CountryCode(dialCode: '+44', code: 'GB'));
  //           _phoneController.text = phoneNumber.substring(dialCode.length);
  //           return;
  //         } else if (dialCode == '+91') {
  //           setState(() => _selectedCountry = CountryCode(dialCode: '+91', code: 'IN'));
  //           _phoneController.text = phoneNumber.substring(dialCode.length);
  //           return;
  //         } else if (dialCode == '+33') {
  //           setState(() => _selectedCountry = CountryCode(dialCode: '+33', code: 'FR'));
  //           _phoneController.text = phoneNumber.substring(dialCode.length);
  //           return;
  //         } else if (dialCode == '+49') {
  //           setState(() => _selectedCountry = CountryCode(dialCode: '+49', code: 'DE'));
  //           _phoneController.text = phoneNumber.substring(dialCode.length);
  //           return;
  //         } else if (dialCode == '+251') {
  //           setState(() => _selectedCountry = CountryCode(dialCode: '+251', code: 'ET'));
  //           _phoneController.text = phoneNumber.substring(dialCode.length);
  //           return;
  //         }
  //       }
  //     }
      
  //     // Check if number starts with 0 (common in UAE)
  //     if (phoneNumber.startsWith('0')) {
  //       setState(() => _selectedCountry = CountryCode(dialCode: '+971', code: 'AE'));
  //       return;
  //     }
      
  //     // Default to UAE
  //     setState(() => _selectedCountry = CountryCode(dialCode: '+971', code: 'AE'));
  //   }
  // }

  Future<void> splitPhoneNumber(String phoneNumber) async {
    try {
      if (phoneNumber.startsWith('0')) {
        setState(() => _selectedCountry = CountryCode(dialCode: '+971', code: 'AE'));
        return;
      }
      // Parse the number
      final parsed = await _phoneNumberUtil.parse(phoneNumber);

      // Extract country code and national number
      final countryCode = parsed.countryCode;
      final nationalNumber = parsed.nationalNumber;

      setState(() {
        _selectedCountry = CountryCode(
          dialCode: '+$countryCode', code: parsed.regionCode, name: parsed.regionCode
        );
        _phoneController.text = nationalNumber;
      });
      
      return;
    } catch (e) {
      throw Exception("Invalid phone number: $e");
    }
  }



  Future<void> _loadContactData() async {
    if (widget.isImported && widget.importedContact != null) {
      // Populate fields from imported contact
      final phoneNumber = widget.importedContact!['phoneNumber'] ?? '';
      setState(() {
        _nameController.text = widget.importedContact!['name'] ?? '';
        _phoneController.text = phoneNumber;
        _emailController.text = widget.importedContact!['email'] ?? '';
        _connectionType = widget.importedContact!['connectionType'] ?? 'Friend';
        _isLoading = false;
      });
      // Initialize country code from phone number
      splitPhoneNumber(phoneNumber);

    } else {
      // Existing logic for regular contacts
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final contacts = await apiService.getContactsStream().first;
        
        final contact = contacts.firstWhere(
          (c) => c.id == widget.contactId,
          orElse: () => Contact(
            id: '',
            name: '',
            connectionType: '',
            frequency: 2,
            period: 'Monthly',
            socialGroups: [],
            phoneNumber: '',
            email: '',
            notes: '',
            imageUrl: '',
            lastContacted: DateTime.now(),
            isVIP: false,
            priority: 3,
            tags: [],
            interactionHistory: {},
          ),
        );
        
        setState(() {
          _originalContact = contact;
          _nameController.text = contact.name;
          _phoneController.text = contact.phoneNumber;
          _emailController.text = contact.email;
          _notesController.text = contact.notes;
          _professionController.text = contact.profession ?? '';
          _socialGroupsController.text = contact.socialGroups.join(', ');
          _connectionType = contact.connectionType;
          _isVIP = contact.isVIP;
          _priority = contact.priority;
          _tags = List.from(contact.tags);
          _birthday = contact.birthday;
          _anniversary = contact.anniversary;
          _workAnniversary = contact.workAnniversary;
          _imageUrl = contact.imageUrl;
          _isLoading = false;
        });
        splitPhoneNumber(contact.phoneNumber);
      }
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

  void _deleteImage() async {
    // If there's an existing image URL, delete it from storage
    if (_imageUrl.isNotEmpty && _imageUrl.contains('https')) {
      try {
        await _storageService.deleteImage(_imageUrl);
      } catch (e) {
        print('Error deleting image: $e');
        // Continue with resetting the UI even if storage deletion fails
      }
    }
    
    setState(() {
      _selectedImage = null;
      _imageUrl = '';
    });
  }

  Widget _buildCropScreen() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    var size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: size.height,
      color: themeProvider.getBackgroundColor(context),
      child: Column(
        children: [
          const SizedBox(height: 100),
          Text(
            'CROP CONTACT PICTURE',
            style: AppTextStyles.title2.copyWith(
              color: themeProvider.getTextPrimaryColor(context),
              fontWeight: FontWeight.w600,
              textBaseline: null,
              decorationColor: Colors.black,
              decorationThickness: 0
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
                      baseColor: themeProvider.isDarkMode ? AppTheme.darkSurface : Colors.white,
                      maskColor: themeProvider.isDarkMode ? AppTheme.darkSurface.withAlpha(150) : Colors.white.withAlpha(100),
                      cornerDotBuilder: (size, edgeAlignment) => DotControl(color: themeProvider.isDarkMode ? AppTheme.primaryColor : Colors.blue),
                    )
                  : Center(child: CircularProgressIndicator(color: themeProvider.isDarkMode ? AppTheme.primaryColor : null)),
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
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Crop', style: TextStyle(color: Colors.white)),
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

  int getRandomIndex(String seed) {
    if (seed.isEmpty) return 1;
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return (hash.abs() % 6) + 1;
  }

  String _getContactInitials(String name) {
    if (name.isEmpty) return '?';
    
    // Trim and split the name by spaces
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.length >= 2) {
      // Has at least first and last name - get first letter of first and last name
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    } else if (parts.length == 1) {
      // Only first name available
      return parts.first[0].toUpperCase();
    }
    
    return '?';
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
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkSurface,
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppTheme.primaryColor,
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

  Future<Map<String, dynamic>> matchSchedule(String groupName, List<SocialGroup> groups) async {
    SocialGroup myGroup = groups.firstWhere((group) => group.name == groupName);
    Map<String, dynamic> schedule = {'period': myGroup.period, 'frequency': myGroup.frequency};
    return schedule;
  }

  // Add this method inside _EditContactScreenState
  bool _isValidPhoneNumber(String phone) {
    String cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanedPhone.length > 12 || cleanedPhone.length < 9) {
      return false;
    }
    
    // if (!RegExp(r'^[0-9]{9}$').hasMatch(cleanedPhone)) {
    //   return false;
    // }
    
    return true;
  }

  // Add this widget method inside _EditContactScreenState
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
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
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

    void _showValidationAlert() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 8),
            Text(
              'Cannot Save Changes',
              style: AppTextStyles.title2.copyWith(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
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
        backgroundColor: themeProvider.getSurfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final feedbackProvider = Provider.of<FeedbackProvider>(context);
    
    if (_isCropping) {
      return _buildCropScreen();
    }

    if (_isLoading) {
      return GestureDetector(
              onTap: _dismissKeyboard,
              child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Contact', style: AppTextStyles.title2.copyWith(color: themeProvider.getTextPrimaryColor(context), fontSize: 22, fontWeight: FontWeight.w800)),
          centerTitle: true,
          iconTheme: IconThemeData(color: AppTheme.primaryColor),
          backgroundColor: themeProvider.getSurfaceColor(context),
        ),
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: 20, right: 6),
          child: FeedbackFloatingButton(),
        ),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      ));
    }

    return StreamProvider<List<SocialGroup>>(
      create: (context) => apiService.getGroupsStream(),
      initialData: [],
      child: Consumer<List<SocialGroup>>(
        builder: (context, groups, child) {
          return GestureDetector(
              onTap: _dismissKeyboard,
              child: Scaffold(
            floatingActionButton: Padding(
              padding: EdgeInsets.only(bottom: 20, right: 6),
              child: FeedbackFloatingButton(),
            ),
            body: Stack(
              children: [
                Scaffold(
                  appBar: AppBar(
              title: Text('Edit Contact', style: AppTextStyles.title2.copyWith(color: themeProvider.getTextPrimaryColor(context), fontSize: 22, fontWeight: FontWeight.w800)),
              centerTitle: true,
              iconTheme: IconThemeData(color: AppTheme.primaryColor),
              backgroundColor: themeProvider.getSurfaceColor(context),
              surfaceTintColor: Colors.transparent,
              actions: [
                IconButton(
                  icon: saving
                  ? SizedBox(
                    width: 25,
                    height: 25,
                    child: CircularProgressIndicator(
                     color: themeProvider.getTextPrimaryColor(context),
                  ),
                  )
                  // Text('...', style: TextStyle(color: themeProvider.getTextPrimaryColor(context)),)
                  : Icon(Icons.save, color: themeProvider.getTextPrimaryColor(context)),
                  onPressed: () => _saveContact(groups),
                  tooltip: 'Save Changes',
                ),
              ],
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
                              width: 200,
                              height: 200,
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
                                          child: Text(
                                            _nameController.text.isNotEmpty ? _getContactInitials(_nameController.text).toUpperCase() : '?',
                                            style: TextStyle(
                                              fontSize: 40,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.white, size: 20),
                                  onPressed: _deleteImage,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name field
                    Text('NAME', style: AppTextStyles.primaryBold.copyWith(color: themeProvider.getTextPrimaryColor(context))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter full name',
                        hintStyle: AppTextStyles.secondary.copyWith(color: themeProvider.getTextHintColor(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: themeProvider.getTextHintColor(context), width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        filled: true,
                        fillColor: themeProvider.getCardColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Connection Type - Now dynamically loaded from user groups
                    Text('CONNECTION TYPE', style: AppTextStyles.primaryBold.copyWith(color: themeProvider.getTextPrimaryColor(context))),
                    const SizedBox(height: 8),
                    _userGroups.isEmpty
                        ? Text('No groups available. Create groups first.', style: TextStyle(color: themeProvider.getTextSecondaryColor(context)))
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
                                    return AppTheme.primaryColor;
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
                        Text('Favourites', style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Phone Number
                    Text('PHONE NUMBER', style: AppTextStyles.primaryBold.copyWith(color: themeProvider.getTextPrimaryColor(context))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: themeProvider.getTextHintColor(context), width: 1),
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
                            textStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context)),
                            searchStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context)),
                            dialogTextStyle: TextStyle(color: themeProvider.getTextPrimaryColor(context)),
                            dialogBackgroundColor: themeProvider.getCardColor(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                            keyboardType: TextInputType.phone,
                            maxLength: 12,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter phone number',
                              hintStyle: AppTextStyles.secondary.copyWith(color: themeProvider.getTextHintColor(context)),
                              counterText: '',
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: themeProvider.getTextHintColor(context), width: 1),
                                borderRadius: BorderRadius.circular(10)
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                borderRadius: BorderRadius.circular(10)
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 1),
                                borderRadius: BorderRadius.circular(10)
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 2),
                                borderRadius: BorderRadius.circular(10)
                              ),
                              filled: true,
                              fillColor: themeProvider.getCardColor(context),
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
                    Text('EMAIL', style: AppTextStyles.primaryBold.copyWith(color: themeProvider.getTextPrimaryColor(context))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        hintStyle: AppTextStyles.secondary.copyWith(color: themeProvider.getTextHintColor(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: themeProvider.getTextHintColor(context), width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        filled: true,
                        fillColor: themeProvider.getCardColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Profession
                    Text('PROFESSION', style: AppTextStyles.primaryBold.copyWith(color: themeProvider.getTextPrimaryColor(context))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _professionController,
                      style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                      decoration: InputDecoration(
                        hintText: 'Enter profession',
                        hintStyle: AppTextStyles.secondary.copyWith(color: themeProvider.getTextHintColor(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: themeProvider.getTextHintColor(context), width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        filled: true,
                        fillColor: themeProvider.getCardColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Social Groups
                    Text('SOCIAL GROUPS', style: AppTextStyles.primaryBold.copyWith(color: themeProvider.getTextPrimaryColor(context))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _socialGroupsController,
                      style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                      decoration: InputDecoration(
                        hintText: 'e.g.: #Highschool #Padel #ComicCon',
                        hintStyle: AppTextStyles.secondary.copyWith(color: themeProvider.getTextHintColor(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: themeProvider.getTextHintColor(context), width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        filled: true,
                        fillColor: themeProvider.getCardColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Important Dates
                    Text('IMPORTANT DATES', style: AppTextStyles.title3.copyWith(color: themeProvider.getTextPrimaryColor(context), fontSize: 18)),
                    const SizedBox(height: 10),

                    // Birthday
                    ListTile(
                      leading: Icon(Icons.cake, color: themeProvider.getTextPrimaryColor(context)),
                      title: Text(
                        _birthday != null
                            ? 'Birthday: ${DateFormat('MMM d, y').format(_birthday!)}'
                            : 'Add Birthday',
                        style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.calendar_today, color: themeProvider.getTextPrimaryColor(context)),
                        onPressed: () => _selectDate(context, isBirthday: true),
                      ),
                    ),

                    // Anniversary
                    ListTile(
                      leading: Icon(Icons.favorite, color: themeProvider.getTextPrimaryColor(context)),
                      title: Text(
                        _anniversary != null
                            ? 'Anniversary: ${DateFormat('MMM d, y').format(_anniversary!)}'
                            : 'Add Anniversary',
                        style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.calendar_today, color: themeProvider.getTextPrimaryColor(context)),
                        onPressed: () => _selectDate(context, isAnniversary: true),
                      ),
                    ),

                    // Work Anniversary
                    ListTile(
                      leading: Icon(Icons.work, color: themeProvider.getTextPrimaryColor(context)),
                      title: Text(
                        _workAnniversary != null
                            ? 'Work Anniversary: ${DateFormat('MMM d, y').format(_workAnniversary!)}'
                            : 'Add Work Anniversary',
                        style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.calendar_today, color: themeProvider.getTextPrimaryColor(context)),
                        onPressed: () => _selectDate(context, isWorkAnniversary: true),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Notes
                    Text('NOTES', style: AppTextStyles.primaryBold.copyWith(color: themeProvider.getTextPrimaryColor(context))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context)),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add any notes about this contact',
                        hintStyle: AppTextStyles.secondary.copyWith(color: themeProvider.getTextHintColor(context)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: themeProvider.getTextHintColor(context), width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        filled: true,
                        fillColor: themeProvider.getCardColor(context),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _saveContact(groups),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: saving ? Colors.grey : AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(saving ? 'SAVING CHANGES...' : 'SAVE CHANGES', style: AppTextStyles.button),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Delete Button
                    if (!widget.isImported) // Only show delete for existing contacts, not imported ones
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _deleteContact,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('DELETE CONTACT', style: AppTextStyles.buttonSecondary.copyWith(color: Colors.red)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
           if (feedbackProvider.isFabMenuOpen)
                  GestureDetector(
                    onTap: () {
                      // Optional: Close the menu when tapping the overlay
                      // You'll need to access the FeedbackFloatingButton's state
                      // This is handled automatically if the button listens to provider changes
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.55),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),
          ]
        )
        ));
        },
      ),
    );
  }

  Future<void> _saveContact(List<SocialGroup> groups) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    if (saving) {
      return;
    }
    // Dismiss keyboard
    _dismissKeyboard();
    
    // Check if form is valid
    if (!_formKey.currentState!.validate()) {
      _showValidationAlert();
      return;
    }
    
    // Check if connection type is selected
    if (_connectionType.isEmpty) {
      _showValidationAlert();
      return;
    }
    print('phase 1');
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      Map<String, dynamic> schedule = await matchSchedule(_connectionType, groups);
      print('phase 2');

      if (user != null) {
        setState(() {
          saving = true;
        });
        if (widget.isImported) {
          // Convert imported contact to regular contact
          final apiService = ApiService();
          
          // Create contact data from form
          final contactData = {
            'name': _nameController.text,
            'phoneNumber': _phoneController.text,
            'email': _emailController.text,
            'connectionType': _connectionType,
            'frequency': schedule['frequency'],
            'period': schedule['period'],
            'socialGroups': _socialGroupsController.text
                .split(',')
                .map((group) => group.trim())
                .where((group) => group.isNotEmpty)
                .toList(),
            'notes': _notesController.text,
            'profession': _professionController.text.isEmpty ? null : _professionController.text,
            'isVIP': _isVIP,
            'priority': _priority,
            'tags': _tags,
          };
          print('phase 3');
          
          await apiService.convertImportedToRegularContact(contactData);
          
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Contact converted successfully')),
          // );
           TopMessageService().showMessage(
            context: context,
            message: 'Contact converted successfully.',
            backgroundColor: Colors.green,
            icon: Icons.check,
          );
          print('phase 4');
        } else if (_originalContact != null) {
          print('subphase1');
          // Upload new image if selected
          String updatedImageUrl = _imageUrl;
          if (_imageBytes != null) {
            try {
              // Delete old image if it exists
              if (_imageUrl.isNotEmpty) {
                await _storageService.deleteImage(_imageUrl);
              }
              print('subphase2');
              // Upload new image
              updatedImageUrl = await uploadImageToFirebase(
                _imageBytes!,
                _originalContact!.id
              );
              print('updated image is'); print (updatedImageUrl);
            } catch (e) {
              print('subphase3');
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(content: Text('Failed to upload image: $e')),
              // );
               TopMessageService().showMessage(
                  context: context,
                  message: 'Failed to upload image: $e',
                  backgroundColor: Colors.green,
                  icon: Icons.check,
                );
              return;
            }
          }
          print('phase 5');
          
          // Create updated contact
          final updatedContact = _originalContact!.copyWith(
            name: _nameController.text,
            connectionType: _connectionType,
            frequency: schedule['frequency'],
            period: schedule['period'],
            socialGroups: _socialGroupsController.text
                .split(',')
                .map((group) => group.trim())
                .where((group) => group.isNotEmpty)
                .toList(),
            phoneNumber: _selectedCountry.dialCode! + _phoneController.text.trim(),
            email: _emailController.text,
            notes: _notesController.text,
            profession: _professionController.text.isEmpty ? null : _professionController.text,
            isVIP: _isVIP,
            priority: _priority,
            tags: _tags,
            birthday: _birthday,
            anniversary: _anniversary,
            workAnniversary: _workAnniversary,
            imageUrl: updatedImageUrl,
          );
          
          // Save to database
          await apiService.updateContact(updatedContact);
          if (_originalContact!.connectionType != updatedContact.connectionType) {
             apiService.cancelNudgesForContacts([updatedContact.id]);
             apiService.scheduleNudgesForContacts(contactIds: [updatedContact.id]);
          }
          if (_originalContact!.birthday != updatedContact.birthday
          || _originalContact!.anniversary != updatedContact.anniversary
          || _originalContact!.workAnniversary != updatedContact.workAnniversary
          ) {
            print('updating birthday');
             apiService.cancelEventNotifications([updatedContact]);
             apiService.scheduleEventNotifications([updatedContact]);
          }
          print('phase 6');

          TopMessageService().showMessage(
            context: context,
            message: 'Contact updated successfully.',
            backgroundColor: Colors.green,
            icon: Icons.check,
          );

        } else {
          print('here');
        }
        setState(() {
          saving = false;
        });
        
        // Navigate back
        Future.delayed(Duration(seconds: 2)).then((value){
          Navigator.pop(context);
        });
      } else {
        print('user is null');
      }
    }
  }

  Future<void> _deleteContact() async {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Contact', style: AppTextStyles.title2.copyWith(color: themeProvider.getTextPrimaryColor(context))),
        content: Text('Are you sure you want to delete ${_nameController.text}? This action cannot be undone.', 
          style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context))),
        backgroundColor: themeProvider.getSurfaceColor(context),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: AppTextStyles.primary.copyWith(color: themeProvider.getTextPrimaryColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: AppTextStyles.primaryBold.copyWith(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.deleteContact(widget.contactId);
        
        Navigator.pop(context);
        
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Contact deleted successfully')),
        // );
        TopMessageService().showMessage(
          context: context,
          message: 'Contact deleted successfully.',
          backgroundColor: Colors.green,
          icon: Icons.check,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _socialGroupsController.dispose();
    _professionController.dispose();
    super.dispose();
  }
}