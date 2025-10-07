// lib/screens/contacts/edit_contact_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
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

  Future<void> _loadContactData() async {
    if (widget.isImported && widget.importedContact != null) {
      // Populate fields from imported contact
      setState(() {
        _nameController.text = widget.importedContact!['name'] ?? '';
        _phoneController.text = widget.importedContact!['phoneNumber'] ?? '';
        _emailController.text = widget.importedContact!['email'] ?? '';
        _connectionType = widget.importedContact!['connectionType'] ?? 'Friend';
        _isLoading = false;
      });
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
      }
    }
  }

  Future<void> _pickImage() async {
    final File? imageFile = await _storageService.pickImage();
    if (imageFile != null) {
      setState(() {
        _selectedImage = imageFile;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('NUDGE', style: AppTextStyles.title3.copyWith(color: Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono'),),
          centerTitle: true,
          iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
          backgroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamProvider<List<SocialGroup>>(
      create: (context) => apiService.getGroupsStream(),
      initialData: [],
      child:  Consumer<List<SocialGroup>>(
          builder: (context, groups, child) {
            return Scaffold(
      appBar: AppBar(
        title: Text('NUDGE', style: AppTextStyles.title3.copyWith(color: Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono'),),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
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
              Padding(
                padding: EdgeInsets.only(left: 10),
                child:  Text('Edit Contact', style: AppTextStyles.primaryBold.copyWith(fontSize: 22)),),
              const SizedBox(height: 30),

              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Color.fromRGBO(45, 161, 175, 1),
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (_imageUrl.isNotEmpty
                                ? NetworkImage(_imageUrl)
                                : null),
                        child: _selectedImage == null && _imageUrl.isEmpty
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

              // Name field
              Text('Name', style: AppTextStyles.primaryBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: AppTextStyles.primary,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Enter full name',
                  hintStyle: AppTextStyles.secondary,
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
              Text('Connection Type', style: AppTextStyles.primaryBold),
              const SizedBox(height: 8),
              _userGroups.isEmpty
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
                  Text('Close Circle', style: AppTextStyles.primary),
                  
                  const SizedBox(width: 20),
                  
                  // Text('Priority:', style: AppTextStyles.primary),
                  // const SizedBox(width: 10),
                  // DropdownButton<int>(
                  //   value: _priority,
                  //   onChanged: (value) {
                  //     setState(() => _priority = value ?? 3);
                  //   },
                  //   items: [1, 2, 3, 4, 5].map((priority) {
                  //     return DropdownMenuItem<int>(
                  //       value: priority,
                  //       child: Text('$priority', style: AppTextStyles.primary),
                  //     );
                  //   }).toList(),
                  // ),
                ],
              ),
              const SizedBox(height: 20),

              // Phone Number
              Text('Phone Number', style: AppTextStyles.primaryBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                style: AppTextStyles.primary,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  hintStyle: AppTextStyles.secondary,
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
              Text('Email', style: AppTextStyles.primaryBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                style: AppTextStyles.primary,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter email address',
                  hintStyle: AppTextStyles.secondary,
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

              // Profession
              Text('Profession', style: AppTextStyles.primaryBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _professionController,
                style: AppTextStyles.primary,
                decoration: InputDecoration(
                  hintText: 'Enter profession',
                  hintStyle: AppTextStyles.secondary,
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
              Text('Social Groups', style: AppTextStyles.primaryBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _socialGroupsController,
                style: AppTextStyles.primary,
                decoration: InputDecoration(
                  hintText: 'e.g.: #Highschool #Padel #ComicCon',
                  hintStyle: AppTextStyles.secondary,
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

              // Important Dates
              Text('Important Dates', style: AppTextStyles.title3),
              const SizedBox(height: 10),

              // Birthday
              ListTile(
                leading: const Icon(Icons.cake),
                title: Text(
                  _birthday != null
                      ? 'Birthday: ${DateFormat('MMM d, y').format(_birthday!)}'
                      : 'Add Birthday',
                  style: AppTextStyles.primary,
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
                  style: AppTextStyles.primary,
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
                  style: AppTextStyles.primary,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context, isWorkAnniversary: true),
                ),
              ),
              const SizedBox(height: 20),

              // Notes
              Text('Notes', style: AppTextStyles.primaryBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                style: AppTextStyles.primary,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any notes about this contact',
                  hintStyle: AppTextStyles.secondary,
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
                  onPressed: () => _saveContact (groups),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Save Changes', style: AppTextStyles.button),
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
                    child: Text('Delete Contact', style: AppTextStyles.buttonSecondary.copyWith(color: Colors.red)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );}));
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

  Future<Map<String, dynamic>> matchSchedule (String groupName, List<SocialGroup> groups) async{
    SocialGroup myGroup = groups.firstWhere((group) => group.name == groupName);
    Map<String, dynamic> schedule = {'period': myGroup.period, 'frequency': myGroup.frequency};
    return schedule;
   }

  Future<void> _saveContact(List<SocialGroup> groups) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    print('phase 1');
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      Map <String, dynamic>  schedule = await matchSchedule(_connectionType, groups);
      print('phase 2');

      if (user != null) {
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
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact converted successfully')),
          );
          print('phase 4');
        } else if (_originalContact != null) {
          
          // Upload new image if selected
          String updatedImageUrl = _imageUrl;
          if (_selectedImage != null) {
            try {
              // Delete old image if it exists
              if (_imageUrl.isNotEmpty) {
                await _storageService.deleteImage(_imageUrl);
              }
              
              // Upload new image
              updatedImageUrl = await _storageService.uploadContactImage(
                _selectedImage!, 
                _originalContact!.id
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to upload image: $e')),
              );
              return;
            }
          }
          print('phase 5');
          
          // Create updated contact
          final updatedContact = _originalContact!.copyWith(
            name: _nameController.text,
            connectionType: _connectionType,
            frequency: schedule['freqency'],
            period: schedule['period'],
            socialGroups: _socialGroupsController.text
                .split(',')
                .map((group) => group.trim())
                .where((group) => group.isNotEmpty)
                .toList(),
            phoneNumber: _phoneController.text,
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
          print('phase 6');
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact updated successfully')),
          );
        }
        
        // Navigate back
        Navigator.pop(context);
      }
    }
  }


  Future<void> _deleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Contact', style: AppTextStyles.title2),
        content: Text('Are you sure you want to delete ${_nameController.text}? This action cannot be undone.', style: AppTextStyles.primary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: AppTextStyles.primary),
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact deleted successfully')),
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