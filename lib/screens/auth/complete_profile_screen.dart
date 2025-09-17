// complete_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nudge/models/user.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../goals/set_goals_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _completeProfile(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final apiService = Provider.of<ApiService>(context, listen: false);
        final user = authService.currentUser;
        
        if (user != null) {
          // Upload image if selected
          String imageUrl = '';
          if (_imageFile != null) {
            // Implement your image upload logic here
            // imageUrl = await uploadImage(_imageFile!);
          }
          
          // Update user with profile information
          await apiService.addUser(User(
            id: user.uid,
            email: user.email!,
            username: _usernameController.text,
            phoneNumber: _phoneController.text,
            bio: _bioController.text,
            description: _descriptionController.text,
            photoURL: imageUrl,
            createdAt: DateTime.now(),
            nudges: [],
            goals: {},
            groups: [
              {"name": "Family", "period": "Monthly", "frequency": 4, "colorCode": "#4FC3F7"},
              {"name": "Friend", "period": "Quarterly", "frequency": 8, "colorCode": "#FF6F61"},
              {"name": "Client", "period": "Monthly", "frequency": 2, "colorCode": "#81C784"},
              {"name": "Colleague", "period": "Annually", "frequency": 4, "colorCode": "#FFC107"},
              {"name": "Mentor", "period": "Annually", "frequency": 2, "colorCode": "#607D8B"},
            ],
            profileCompleted: true, // Mark profile as completed
          ));
          
          // Navigate to goals screen
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const SetGoalsScreen(isFromSettings: false)),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NUDGE', style: AppTextStyles.title2.copyWith(color: Colors.white),),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Profile Image
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _imageFile != null 
                        ? FileImage(_imageFile!) 
                        : null,
                    child: _imageFile == null
                        ? const Icon(Icons.camera_alt, size: 40)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Username
              const Text(
                'Username',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Enter username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Phone Number
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Bio
              const Text(
                'Bio',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(
                  hintText: 'Short bio about yourself',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a bio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Description
              // const Text(
              //   'Description',
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     fontSize: 16,
              //   ),
              // ),
              // const SizedBox(height: 8),
              // TextFormField(
              //   controller: _descriptionController,
              //   decoration: InputDecoration(
              //     hintText: 'Tell us more about yourself',
              //     border: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(10),
              //     ),
              //   ),
              //   maxLines: 3,
              //   validator: (value) {
              //     if (value == null || value.isEmpty) {
              //       return 'Please enter a description';
              //     }
              //     return null;
              //   },
              // ),
              const SizedBox(height: 30),
              
              // Complete Profile Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () => _completeProfile(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Complete Profile',
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
}