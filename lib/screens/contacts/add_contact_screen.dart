// lib/screens/contacts/add_contact_screen.dart
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/theme/text_styles.dart';
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

class AddContactScreen extends StatefulWidget {
  final String? groupName;
  final String? groupPeriod;
  final int? groupFrequency;
  
  const AddContactScreen({super.key, this.groupName, this.groupPeriod, this.groupFrequency});

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

  @override
  void initState() {
    super.initState();
    // Load tag suggestions based on existing contacts
     if (widget.groupName != null) {
      _connectionType = widget.groupName!;
    }
    
    _loadTagSuggestions();
    _loadUserGroups();
    
  }

  void _loadUserGroups() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final groups = await apiService.getGroupsStream().first;
        
        setState(() {
          _userGroups = groups;
          if (_userGroups.isNotEmpty) {
            _connectionType = _userGroups.first.name;
          }
        });
      }
    } catch (e) {
      print('Error loading user groups: $e');
    }
  }

  void _loadTagSuggestions() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    final apiService = ApiService();
    final contacts = await apiService.getContactsStream() as List<dynamic>;
    
    // Get unique tags from all contacts
    Set<String> allTags = {};
    for (var contact in contacts) {
      allTags.addAll(contact.tags);
    }
    
    setState(() {
      _tagSuggestions = allTags.toList();
    });
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

  Future<Map<String, dynamic>> matchSchedule (String groupName, List<SocialGroup> groups) async{
    print(groupName);
    SocialGroup myGroup = groups.firstWhere((group) => group.id == groupName);
    Map<String, dynamic> schedule = {'period': myGroup.period, 'frequency': myGroup.frequency};
    return schedule;
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
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
    var size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: size.height,
      color: Colors.white,
      child: Column(
      children: [
        const SizedBox(height: 100),
        Text(
          'Crop Contact Picture',
          style: AppTextStyles.title2.copyWith(
            color: Colors.black, fontFamily: 'QuickSand',
            fontWeight: FontWeight.w600, textBaseline: null,
            decorationColor: Colors.black, decorationThickness: 0
          ),
          // style: TextStyle(
          //   fontSize: 18, 
          //   fontWeight: FontWeight.w500, 
          //   decoration: TextDecoration.underline, 
          //   decorationColor: Colors.transparent,
          //   color: Colors.black,
          //   ),
        ),
        // const SizedBox(height: 10),
        // const Text(
        //   'Adjust the square to frame the photo',
        //   style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
        // ),
        // const SizedBox(height: 20),
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
                    baseColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
     if (_isCropping) {
        return _buildCropScreen();
      }
    final authService = Provider.of<AuthService>(context);
    final apiService = Provider.of<ApiService>(context);
    final user = authService.currentUser;
    
    return StreamProvider<List<SocialGroup>>(
        create: (context) => apiService.getGroupsStream(),
        initialData: const [],
        child: Consumer<List<SocialGroup>>(
          builder: (context, groups, child) {
            return Scaffold(
                appBar: AppBar(
                  title: Text('NUDGE', style: AppTextStyles.title3.copyWith(color: Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono'),),
                  centerTitle: true,
                  iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
                  backgroundColor: Colors.white
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Contact',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: CircleAvatar(
                                  radius: 80,
                                  backgroundColor: Color.fromRGBO(45, 161, 175, 1),
                                  backgroundImage: _imageBytes != null
                                      ? MemoryImage(_imageBytes!)
                                      : (_imageUrl.isNotEmpty
                                          ? NetworkImage(_imageUrl)
                                          : null),
                                  child: _imageBytes == null && _imageUrl.isEmpty
                                      ? const Icon(Icons.camera_alt, size: 40)
                                      : null,
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

                        const Text(
                          'Add details below',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Name field
                        const Text(
                          'Name *',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                          decoration: InputDecoration(
                            hintText: 'Enter full name',
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
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Connection Type - Now dynamically loaded from user groups
                        const Text(
                          'Connection Type *',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        widget.groupName!=null
                        ? ConnectionTypeChip(
                                    label: widget.groupName!,
                                    isSelected: true,
                                    onSelected: (selected) {
                                      
                                    },
                                  )
                        :_userGroups.isEmpty
                            ? const Text('No groups available. Create groups first.', style: TextStyle(color: Colors.grey))
                            : Wrap(
                                spacing: 8,
                                runSpacing: 10,
                                children: _userGroups.map((group) {
                                  return ConnectionTypeChip(
                                    label: group.name,
                                    isSelected: _connectionType == group.id,
                                    onSelected: (selected) {
                                      if (selected) setState(() => _connectionType = group.id);
                                    },
                                  );
                                }).toList(),
                              ),
                        
                        const SizedBox(height: 20),
                        
                        // VIP and Priority
                        Row(
                          children: [
                            Checkbox(
                              value: _isVIP,
                              onChanged: (value) {
                                setState(() => _isVIP = value ?? false);
                              },
                            ),
                            const Text('Close Circle'),
                            
                            const SizedBox(width: 20),
                            
                            // const Text('Priority:'),
                            // const SizedBox(width: 10),
                            // DropdownButton<int>(
                            //   value: _priority,
                            //   onChanged: (value) {
                            //     setState(() => _priority = value ?? 3);
                            //   },
                            //   items: [1, 2, 3, 4, 5].map((priority) {
                            //     return DropdownMenuItem<int>(
                            //       value: priority,
                            //       child: Text('$priority'),
                            //     );
                            //   }).toList(),
                            // ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Profession
                        const Text(
                          'Profession',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _professionController,
                          decoration: InputDecoration(
                            hintText: 'Enter profession',
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
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Important Dates Section
                        const Text(
                          'Important Dates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Birthday
                        ListTile(
                          leading: const Icon(Icons.cake),
                          title: Text(
                            _birthday != null
                                ? 'Birthday: ${DateFormat('MMM d, y').format(_birthday!)}'
                                : 'Add Birthday',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _selectDate(context, isBirthday: true),
                          ),
                        ),
                        
                        // Anniversary
                        ListTile(
                          leading: const Icon(Icons.favorite),
                          title: Text(
                            _anniversary != null
                                ? 'Anniversary: ${DateFormat('MMM d, y').format(_anniversary!)}'
                                : 'Add Anniversary',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _selectDate(context, isAnniversary: true),
                          ),
                        ),
                        
                        // Work Anniversary
                        ListTile(
                          leading: const Icon(Icons.work),
                          title: Text(
                            _workAnniversary != null
                                ? 'Work Anniversary: ${DateFormat('MMM d, y').format(_workAnniversary!)}'
                                : 'Add Work Anniversary',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _selectDate(context, isWorkAnniversary: true),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Tags
                        const Text(
                          'Social Groups',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        
                        // Tag suggestions
                        if (_tagSuggestions.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            children: _tagSuggestions.map((tag) {
                              return FilterChip(
                                label: Text(tag),
                                selected: _tags.contains(tag),
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
                        
                        // Add new tag
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tagsController,
                                decoration: InputDecoration(
                                  hintText: 'Add new Social Group',
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
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (_tagsController.text.isNotEmpty) {
                                  setState(() {
                                    _tags.add(_tagsController.text);
                                    _tagsController.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        
                        // Display selected tags
                        Wrap(
                          spacing: 8,
                          children: _tags.map((tag) {
                            return Chip(
                              label: Text(tag),
                              onDeleted: () {
                                setState(() => _tags.remove(tag));
                              },
                            );
                          }).toList(),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Phone Number
                        const Text(
                          'Phone Number',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Enter phone number',
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
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Email
                        const Text(
                          'Email',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter email address',
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
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Social Groups
                        // const Text(
                        //   'Social Groups',
                        //   style: TextStyle(fontWeight: FontWeight.bold),
                        // ),
                        // const SizedBox(height: 8),
                        // TextFormField(
                        //   controller: _socialGroupsController,
                        //   decoration: InputDecoration(
                        //     hintText: 'e.g.: #Highschool #Padel #ComicCon',
                        //     border: OutlineInputBorder(
                        //       borderRadius: BorderRadius.circular(10),
                        //     ),
                        //   ),
                        // ),
                        
                        const SizedBox(height: 20),
                        
                        // Notes
                        const Text(
                          'Notes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add any notes about this contact',
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
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                         onPressed: () async {
                            print('stage0');
                            if (_formKey.currentState!.validate() && user != null) {
                              // Upload image if selected
                              if (_imageBytes != null) {
                                try {
                                  _imageUrl = await uploadImageToFirebase(_imageBytes!, 'new_contact_${DateTime.now().millisecondsSinceEpoch}');
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to upload image: $e')),
                                  );
                                  return;
                                }
                              }

                              // Use group settings if provided, otherwise use default matching
                              String period;
                              int frequency;
                              print('stage1');
                              
                              if (widget.groupPeriod != null && widget.groupFrequency != null) {
                                period = widget.groupPeriod!;
                                frequency = widget.groupFrequency!;
                              } else {
                                Map<String, dynamic> schedule = await matchSchedule(_connectionType, groups);
                                period = schedule['period'];
                                frequency = schedule['frequency'];
                              }
                              print('stage2');
                              
                              final newContact = Contact(
                                id: '', // Will be generated by Firestore
                                name: _nameController.text,
                                connectionType: _connectionType,
                                frequency: frequency,
                                period: period,
                                socialGroups: _socialGroupsController.text
                                    .split(' ')
                                    .where((group) => group.startsWith('#'))
                                    .map((group) => group.substring(1))
                                    .toList(),
                                phoneNumber: _phoneController.text,
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
                              print('stage3');
                              
                              // Automatically schedule nudge based on connection category
                              try {
                                final nudgeService = NudgeService();
                                await nudgeService.scheduleNudgeForContact(
                                  newContact, 
                                  user.uid,
                                  period: period,
                                  frequency: frequency,
                                );
                                print('Automatic nudge scheduled for ${newContact.name}');
                              } catch (e) {
                                print('Error scheduling automatic nudge: $e');
                                // Don't show error to user - nudge scheduling is secondary
                              }
                              
                              // Navigate back
                              Navigator.pop(context);
                            }
                          },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Save Contact',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
    }));
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _socialGroupsController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    _professionController.dispose();
    super.dispose();
  }
}