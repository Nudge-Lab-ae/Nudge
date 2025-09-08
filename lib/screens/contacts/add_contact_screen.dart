// lib/screens/contacts/add_contact_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:provider/provider.dart';
// import '../../services/database_service.dart';
import '../../services/auth_service.dart';
// import '../../services/tagging_service.dart';
import '../../models/contact.dart';
import '../../widgets/connection_type_chip.dart';
import 'dart:io';
// import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

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
  File? _selectedImage;
  String _imageUrl = '';
  final StorageService _storageService = StorageService();
  
  String _connectionType = 'Friend';
  String _frequency = 'Monthly';
  bool _isVIP = false;
  int _priority = 3;
  List<String> _tags = [];
  List<String> _tagSuggestions = [];

  @override
  void initState() {
    super.initState();
    // Load tag suggestions based on existing contacts
    _loadTagSuggestions();
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
    final File? imageFile = await _storageService.pickImage();
    if (imageFile != null) {
      setState(() {
        _selectedImage = imageFile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final apiService = Provider.of<ApiService>(context);
    final user = authService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Contact', style: TextStyle(color: Colors.white),),
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
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
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Connection Type
              const Text(
                'Connection Type *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: [
                  ConnectionTypeChip(
                    label: 'Family',
                    isSelected: _connectionType == 'Family',
                    onSelected: (selected) {
                      if (selected) setState(() => _connectionType = 'Family');
                    },
                  ),
                  ConnectionTypeChip(
                    label: 'Friend',
                    isSelected: _connectionType == 'Friend',
                    onSelected: (selected) {
                      if (selected) setState(() => _connectionType = 'Friend');
                    },
                  ),
                  ConnectionTypeChip(
                    label: 'Colleague',
                    isSelected: _connectionType == 'Colleague',
                    onSelected: (selected) {
                      if (selected) setState(() => _connectionType = 'Colleague');
                    },
                  ),
                  ConnectionTypeChip(
                    label: 'Client',
                    isSelected: _connectionType == 'Client',
                    onSelected: (selected) {
                      if (selected) setState(() => _connectionType = 'Client');
                    },
                  ),
                  ConnectionTypeChip(
                    label: 'Mentor',
                    isSelected: _connectionType == 'Mentor',
                    onSelected: (selected) {
                      if (selected) setState(() => _connectionType = 'Mentor');
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Contact Frequency
              const Text(
                'Contact Frequency *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Wrap(
              //   spacing: 8,
              //   children: [
              //     ConnectionTypeChip(
              //       label: 'Weekly',
              //       isSelected: _frequency == 'Weekly',
              //       onSelected: (selected) {
              //         if (selected) setState(() => _frequency = 'Weekly');
              //       },
              //     ),
              //     ConnectionTypeChip(
              //       label: 'Monthly',
              //       isSelected: _frequency == 'Monthly',
              //       onSelected: (selected) {
              //         if (selected) setState(() => _frequency = 'Monthly');
              //       },
              //     ),
              //     ConnectionTypeChip(
              //       label: 'Quarterly',
              //       isSelected: _frequency == 'Quarterly',
              //       onSelected: (selected) {
              //         if (selected) setState(() => _frequency = 'Quarterly');
              //       },
              //     ),
              //     ConnectionTypeChip(
              //       label: 'Annually',
              //       isSelected: _frequency == 'Annually',
              //       onSelected: (selected) {
              //         if (selected) setState(() => _frequency = 'Annually');
              //       },
              //     ),
              //   ],
              // ),
              
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
                  const Text('VIP Contact'),
                  
                  const SizedBox(width: 20),
                  
                  const Text('Priority:'),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: _priority,
                    onChanged: (value) {
                      setState(() => _priority = value ?? 3);
                    },
                    items: [1, 2, 3, 4, 5].map((priority) {
                      return DropdownMenuItem<int>(
                        value: priority,
                        child: Text('$priority'),
                      );
                    }).toList(),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Tags
              const Text(
                'Tags',
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
                        hintText: 'Add new tag',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Social Groups
              const Text(
                'Social Groups',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _socialGroupsController,
                decoration: InputDecoration(
                  hintText: 'e.g.: #Highschool #Padel #ComicCon',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
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
                    if (_formKey.currentState!.validate() && user != null) {
                      // Create new contact

                       // Upload image if selected
                      if (_selectedImage != null) {
                        try {
                          _imageUrl = await _storageService.uploadContactImage(_selectedImage!, 'new_contact_${DateTime.now().millisecondsSinceEpoch}');
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to upload image: $e')),
                          );
                          return;
                        }
                      }
                      
                      final newContact = Contact(
                        id: '', // Will be generated by Firestore
                        name: _nameController.text,
                        connectionType: _connectionType,
                        frequency: _frequency,
                        socialGroups: _socialGroupsController.text
                            .split(' ')
                            .where((group) => group.startsWith('#'))
                            .map((group) => group.substring(1))
                            .toList(),
                        phoneNumber: _phoneController.text,
                        email: _emailController.text,
                        notes: _notesController.text,
                        imageUrl: '', // Will be handled separately
                        lastContacted: DateTime.now(),
                        isVIP: _isVIP,
                        priority: _priority,
                        tags: _tags,
                        // relationshipDepth: TaggingService.suggestRelationshipDepth(
                        //   Contact(
                        //     id: '',
                        //     name: _nameController.text,
                        //     connectionType: _connectionType,
                        //     frequency: _frequency,
                        //     socialGroups: [],
                        //     phoneNumber: _phoneController.text,
                        //     email: _emailController.text,
                        //     notes: _notesController.text,
                        //     imageUrl: '',
                        //     lastContacted: DateTime.now(),
                        //     isVIP: _isVIP,
                        //     priority: _priority,
                        //     tags: _tags,
                        //     interactionHistory: {},
                        //   )
                        // ),
                        interactionHistory: {},
                      );
                      
                      // Save to Firestore
                      // final databaseService = DatabaseService(uid: user.uid);
                      await apiService.addContact(newContact);
                      
                      // Navigate back
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
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
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _socialGroupsController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }
}