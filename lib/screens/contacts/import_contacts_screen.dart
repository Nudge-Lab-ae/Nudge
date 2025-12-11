// lib/screens/contacts/import_contacts_screen.dart
import 'dart:io';
// import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/models/user.dart';
import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
// import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;

import '../../services/contact_sync_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class ImportContactsScreen extends StatefulWidget {
  const ImportContactsScreen({super.key});

  @override
  State<ImportContactsScreen> createState() => _ImportContactsScreenState();
}

class _ImportContactsScreenState extends State<ImportContactsScreen> {
  bool _isImporting = false;
  int _processedCount = 0;
  int _totalCount = 0;
  String _statusMessage = '';
  int _selectedQuantity = 50;
  bool _useSmartFilter = true;
  final List<int> _quantityOptions = [25, 50, 100, 150];

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

  Future<void> _importDeviceContacts() async {
  setState(() {
    _isImporting = true;
    _processedCount = 0;
    _totalCount = 0;
    _statusMessage = 'Checking for existing contacts...';
  });

  final authService = Provider.of<AuthService>(context, listen: false);
  final apiService = Provider.of<ApiService>(context, listen: false);
  final user = authService.currentUser;
  if (user == null) {
    setState(() => _isImporting = false);
    return;
  }

  final syncService = ContactSyncService(apiService: apiService);

  try {
    // Get passed groups from route arguments (if any)
    final apiService = Provider.of<ApiService>(context, listen: false);
    // final passedGroups = ModalRoute.of(context)?.settings.arguments as List<SocialGroup>?;
    List<SocialGroup> allGroups = [];
    User thisUser = await apiService.getUser();
    var userGroups = thisUser.groups;
    for (int i=0; i<userGroups!.length; i++) {
      allGroups.add(SocialGroup.fromMap(userGroups[i]));
    }
    print('groups are'); print(userGroups); print(allGroups);
    
    // Show group selection dialog with passed groups (if available)
    final SocialGroup? selectedGroup = await _showGroupSelectionDialog(allGroups);
    if (selectedGroup == null) {
      setState(() => _isImporting = false);
      return; // User cancelled group selection
    }

    final result = await syncService.importDeviceContacts(
      limit: _selectedQuantity,
      useSmartFilter: _useSmartFilter,
      groupId: selectedGroup.name, // Pass the group ID
      onProgress: (processed, total) {
        setState(() {
          _processedCount = processed;
          _totalCount = total;
          _statusMessage = 'Processing $processed of $total contacts...';
        });
      },
    );

    setState(() => _isImporting = false);
    final importedContacts = await apiService.getAllContacts();

    if (result['needsSettings'] == true) {
      _showSettingsDialog(result['message']);
      return;
    }

    if (result['success'] == true) {
      if (result['importedCount'] == 0) {
        setState(() {
          _statusMessage =
              'No new contacts to import - all contacts already exist in Nudge';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All contacts already imported')),
        );
        
        // Return empty list to parent screen
        Navigator.pop(context, importedContacts);
      } else {
        setState(() {
          _statusMessage =
              'Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!';
        });

        // Get the actual imported contacts from API
        final importedContacts = await apiService.getAllContacts();
        // final recentlyImportedContacts = importedContacts
        //     .where((contact) => contact.socialGroups.contains(selectedGroup.name))
        //     .toList();

        // _scheduleNudgesForImportedContacts(result['importedCount'], user.uid);
        
        // Return the imported contacts to parent screen
        Navigator.pop(context, importedContacts);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!'),
          ),
        );
      }
    } else {
      setState(() {
        _statusMessage = 'Import failed: ${result['message']}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import contacts: ${result['message']}')),
      );
      
      // Return empty list on failure
      Navigator.pop(context, []);
    }
  } catch (e) {
    setState(() {
      _isImporting = false;
      _statusMessage = 'Error: $e';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to import contacts: $e')),
    );
    
    // Return empty list on error
    Navigator.pop(context, []);
  }
}

  Future<SocialGroup?> _showGroupSelectionDialog(List<SocialGroup>? passedGroups) async {
  List<SocialGroup> availableGroups = [];
  
  // If groups are passed in (from onboarding), use them
  if (passedGroups != null && passedGroups.isNotEmpty) {
    availableGroups = passedGroups;
  } else {
    // Otherwise, try to get groups from API
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      // final authService = Provider.of<AuthService>(context, listen: false);
      final user = await apiService.getUser();
      
      if (user.username != '') {
        final groups = user.groups;
        groups!.map((e){
          availableGroups.add(SocialGroup.fromMap(e));
        });
      }
    } catch (e) {
      print('Error getting groups: $e');
    }
  }
  
  // If still no groups, create default ones
  if (availableGroups.isEmpty) {
    availableGroups = [
      SocialGroup(
        id: 'Family', 
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
        id: 'Friend', 
        name: 'Friend', 
        frequency: 8,
        period: 'Quarterly',
        colorCode: '#FF6F61', 
        description: '', 
        memberCount: 0, 
        memberIds: [], 
        lastInteraction: DateTime.now(), 
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
      ),
      SocialGroup(
        id: 'Colleague', 
        name: 'Colleague', 
        frequency: 4,
        period: 'Annually',
        colorCode: '#81C784', 
        description: '', 
        memberCount: 0, 
        memberIds: [], 
        lastInteraction: DateTime.now(), 
        birthdayNudgesEnabled: true,
        anniversaryNudgesEnabled: true,
      ),
      SocialGroup(
        id: 'Mentor', 
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
      ),
      SocialGroup(
        id: 'Client', 
        name: 'Client', 
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
    ];
  }
  
  
  // Show dialog for group selection
  return await showDialog<SocialGroup>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Select Group'),
      content: Container(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: availableGroups.length,
          itemBuilder: (context, index) {
            final group = availableGroups[index];
            return Card(
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
                title: Text(group.name),
                subtitle: Text(_getCurrentFrequencyChoice(group)),
                onTap: () => Navigator.pop(context, group),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}  

String _getCurrentFrequencyChoice(SocialGroup group) {
  return FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period);
}

//   void _showImportSuccessAndScheduleNudges(int importedCount, String userId) async {
//   // Show initial success message
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(
//       content: Row(
//         children: [
//           const Icon(Icons.check_circle, color: Colors.white),
//           const SizedBox(width: 8),
//           Text('Imported $importedCount contacts successfully!'),
//         ],
//       ),
//       backgroundColor: Colors.green,
//     ),
//   );

//   // Schedule nudges in background
//   await _scheduleNudgesForImportedContacts(importedCount, userId);
// }

  /// Full-screen multi-select picker UI.
  /// This fetches contacts, shows a checkbox list in full screen, and imports the selected ones.
Future<void> _pickContactsAndImport() async {
    final permissionOk = await fContacts.FlutterContacts.requestPermission();
    if (!permissionOk) {
      _showSettingsDialog('Contacts permission is required to pick contacts');
      return;
    }

    final contacts = await fContacts.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true, // ✅ request photos
    );

    final selectedContacts = await Navigator.of(context).push<List<fContacts.Contact>>(
      MaterialPageRoute(
        builder: (context) => _FullScreenContactPicker(contacts: contacts),
        fullscreenDialog: true,
      ),
    );

    if (selectedContacts == null || selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts selected')),
      );
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    List<SocialGroup> allGroups = [];
    User thisUser = await apiService.getUser();
    var userGroups = thisUser.groups;
    for (int i = 0; i < userGroups!.length; i++) {
      allGroups.add(SocialGroup.fromMap(userGroups[i]));
    }

    final SocialGroup? selectedGroup = await _showGroupSelectionDialog(allGroups);
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group selection cancelled')),
      );
      return;
    }

    final user = authService.currentUser;
    if (user == null) return;

    final syncService = ContactSyncService(apiService: apiService);

    setState(() {
      _isImporting = true;
      _processedCount = 0;
      _totalCount = selectedContacts.length;
      _statusMessage = 'Importing selected contacts to ${selectedGroup.name}...';
    });

    final result = await syncService.importFromContactPicker(
      pickedContacts: selectedContacts,
      groupId: selectedGroup.name,
      onProgress: (processed, total) {
        setState(() {
          _processedCount = processed;
          _totalCount = total;
          _statusMessage = 'Processing $processed of $total contacts...';
        });
      },
    );

    setState(() => _isImporting = false);

    if (result['success'] == true) {
      setState(() {
        _statusMessage =
            'Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!';
      });

      final importedContacts = await apiService.getAllContacts();
      final recentlyImportedContacts = importedContacts
          .where((contact) => contact.socialGroups.contains(selectedGroup.name))
          .toList();

      Navigator.pop(context, recentlyImportedContacts);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!'),
        ),
      );
      _scheduleNudgesForImportedContacts(result['importedCount'], user.uid);
    } else {
      setState(() {
        _statusMessage = 'Import failed: ${result['message']}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import contacts: ${result['message']}')),
      );
    }
  }


  String _getQuantityLabel(int quantity) {
    return quantity == 0 ? 'All Contacts' : 'First $quantity Contacts';
  }

  // Add to _ImportContactsScreenState class in import_contacts_screen.dart

 Future<void> _scheduleNudgesForImportedContacts(int importedCount, String userId) async {
  final apiService = Provider.of<ApiService>(context, listen: false);
  final nudgeService = NudgeService();
  
  try {
    // Show scheduling indicator
    setState(() {
      _statusMessage = 'Scheduling nudges for imported contacts...';
      _isImporting = true;
    });

    // Get the updated contacts list
    final contacts = await apiService.getAllContacts();
    
    // Schedule nudges for newly imported contacts
    int scheduledCount = 0;
    for (final contact in contacts) {
      // Use default settings for imported contacts
      final success = await nudgeService.scheduleNudgeForContact(
        contact,
        userId,
        period: 'Monthly',
        frequency: 2,
      );
      
      if (success) scheduledCount++;
    }
    
    setState(() {
      _isImporting = false;
    });

    if (scheduledCount > 0) {
      _showNudgeScheduledMessage(scheduledCount);
    }
  } catch (e) {
    setState(() {
      _isImporting = false;
    });
    print('Error scheduling nudges: $e');
    // Don't show error to user as this is background process
  }
}

void _showNudgeScheduledMessage(int scheduledCount) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Automatic Nudge Scheduling',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nudges scheduled for $scheduledCount contacts. You\'ll receive reminders automatically!',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
      backgroundColor: const Color(0xff3CB3E9),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

@override
  void initState() {
    super.initState();
    // For iOS, immediately open the contact picker
  }


@override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    
    // For iOS, show a simplified screen or directly open picker
    if (Platform.isIOS) {
      return _buildIOSVersion();
    }
    
    // For Android, show the full import options
    return _buildAndroidVersion(size);
  }

  Widget _buildIOSVersion() {
    return Scaffold(
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
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
        backgroundColor: Colors.white,
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.4),
        child: FeedbackFloatingButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.contacts,
              size: 80,
              color: Color(0xff3CB3E9),
            ),
            const SizedBox(height: 24),
            const Text(
              'IMPORT YOUR CONTACTS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xff555555),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Select contacts from your device to import into Nudge',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xff555555),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // iOS-specific note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(45, 161, 175, 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Color(0xff3CB3E9), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'iOS Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xff3CB3E9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'On iOS, you can manually select which contacts to import. '
                    'Simply tap the button below to open your contacts list and make your selections.',
                    style: TextStyle(fontSize: 14, color: Color(0xff555555)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _pickContactsAndImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3CB3E9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.import_contacts, color: Colors.white),
                label: _isImporting
                    ? const Text('Importing...', style: TextStyle(color: Colors.white))
                    : const Text('Select Contacts to Import', 
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            
            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, []);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.grey),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidVersion(Size size) {
    return Scaffold(
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
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
        backgroundColor: Colors.white,
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: size.height * 0.4),
        child: FeedbackFloatingButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              'IMPORT YOUR CONTACTS',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff555555)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Easily import your existing contacts to get started with Nudge',
              style: TextStyle(fontSize: 16, color: Color(0xff555555), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 30),

            // Import Options Card - Android only
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IMPORT OPTIONS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff6e6e6e)),
                    ),
                    const SizedBox(height: 16),

                    // Quantity Selection - Android only
                    const Text(
                      'How many contacts would you like to import?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xff555555)),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quantityOptions.map((quantity) {
                        return FilterChip(
                          label: Text(_getQuantityLabel(quantity)),
                          selected: _selectedQuantity == quantity,
                          onSelected: (selected) {
                            setState(() {
                              _selectedQuantity = selected ? quantity : 0;
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: const Color.fromRGBO(45, 161, 175, 0.2),
                          checkmarkColor: const Color(0xff3CB3E9),
                          labelStyle: TextStyle(
                            color: _selectedQuantity == quantity
                                ? const Color(0xff3CB3E9)
                                : Color(0xff555555),
                            fontWeight: _selectedQuantity == quantity
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Smart Filter Option - Android only
                    Row(
                      children: [
                        Switch(
                          value: _useSmartFilter,
                          onChanged: (value) {
                            setState(() {
                              _useSmartFilter = value;
                            });
                          },
                          activeColor: const Color(0xff3CB3E9),
                          inactiveTrackColor: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SMART FILTER',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xff6e6e6e)),
                              ),
                              Text(
                                'Prioritize contacts you interact with most',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Buttons: import device contacts + pick selected contacts
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isImporting ? null : _importDeviceContacts,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff3CB3E9),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isImporting
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Importing...', style: TextStyle(color: Colors.white)),
                                    ],
                                  )
                                : const Text(
                                    'Start Import',
                                    style: TextStyle(fontSize: 16, color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isImporting ? null : _pickContactsAndImport,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Color(0xff3CB3E9)),
                            ),
                            icon: const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(Icons.group_add, color: Color(0xff3CB3E9)),
                            ),
                            label: const Text(
                              'Pick & Import Selected',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xff3CB3E9),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Progress Section
            if (_isImporting) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import Progress',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      LinearProgressIndicator(
                        value: _totalCount > 0 ? _processedCount / _totalCount : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Color(0xff3CB3E9)),
                        borderRadius: BorderRadius.circular(4),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _statusMessage,
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            '$_processedCount/$_totalCount',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Results Section
            if (!_isImporting && _statusMessage.isNotEmpty) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import Successful',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _statusMessage,
                              style: TextStyle(
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Information Section - Android only
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW IT WORKS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff6e6e6e)),
                    ),
                    SizedBox(height: 12),
                    ListTile(
                      leading: Icon(Icons.filter_list, color: Color(0xff3CB3E9)),
                      title: Text('Smart Filter', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xff555555))),
                      subtitle: Text('Prioritizes contacts based on your interaction frequency', style: TextStyle(color: Color(0xff555555)),),
                    ),
                    ListTile(
                      leading: Icon(Icons.group, color: Color(0xff3CB3E9)),
                      title: Text('Customizable Quantity', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xff555555))),
                      subtitle: Text('Choose how many contacts to import based on your needs', style: TextStyle(color: Color(0xff555555)),),
                    ),
                    ListTile(
                      leading: Icon(Icons.security, color: Color(0xff3CB3E9)),
                      title: Text('Privacy First', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xff555555))),
                      subtitle: Text('Your contacts are only stored on your device and our secure servers', style: TextStyle(color: Color(0xff555555)),),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen contact picker widget for selecting contacts to import
class _FullScreenContactPicker extends StatefulWidget {
  final List<fContacts.Contact> contacts;

  const _FullScreenContactPicker({required this.contacts});

  @override
  __FullScreenContactPickerState createState() => __FullScreenContactPickerState();
}

class __FullScreenContactPickerState extends State<_FullScreenContactPicker> {
  final List<fContacts.Contact> _tempSelected = [];
  final TextEditingController _searchController = TextEditingController();
  List<fContacts.Contact> _filteredContacts = [];
  
  // Cache for avatar indices to maintain consistency
  final Map<String, int> _avatarIndexCache = {};

  @override
  void initState() {
    super.initState();
    _filteredContacts = List.of(widget.contacts);
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredContacts = q.isEmpty
          ? List.of(widget.contacts)
          : widget.contacts.where((c) {
              final name = c.displayName.toLowerCase();
              final phones = c.phones.map((p) => p.number.toLowerCase()).join(' ');
              final emails = c.emails.map((e) => e.address.toLowerCase()).join(' ');
              return name.contains(q) || phones.contains(q) || emails.contains(q);
            }).toList();
    });
  }

  // Get cached or new random index for avatar
  int _getAvatarIndex(fContacts.Contact contact) {
    // Use contact ID as cache key if available, otherwise use display name
    final cacheKey = contact.id;
    
    if (_avatarIndexCache.containsKey(cacheKey)) {
      return _avatarIndexCache[cacheKey]!;
    }
    
    // Generate random index (1-6) using the same logic as contacts list
    final seed = cacheKey.isEmpty ? 'default' : cacheKey;
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = (hash.abs() % 6) + 1;
    
    // Cache the result
    _avatarIndexCache[cacheKey] = index;
    return index;
  }

  void _selectAllFiltered() {
    setState(() {
      for (final c in _filteredContacts) {
        if (!_tempSelected.contains(c)) {
          _tempSelected.add(c);
        }
      }
    });
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

  void _clearFilteredSelection() {
    setState(() {
      _tempSelected.removeWhere((c) => _filteredContacts.contains(c));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SELECT CONTACTS', style: TextStyle(color: Color(0xff555555), fontSize: 16, fontWeight: FontWeight.w600),),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select all',
            onPressed: _selectAllFiltered,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear selection',
            onPressed: _clearFilteredSelection,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              '${_tempSelected.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by name, phone, or email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: _applyFilter,
            ),
          ),
          
          // Info bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${_filteredContacts.length} of ${widget.contacts.length} contacts',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                Text(
                  'Selected: ${_tempSelected.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Divider
          const Divider(height: 1),
          
          // Contacts list
          Expanded(
            child: _filteredContacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.group_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No contacts found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        if (_searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Try a different search term',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final isSelected = _tempSelected.contains(contact);
                      final primaryPhone = contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : '';
                      final primaryEmail = contact.emails.isNotEmpty
                          ? contact.emails.first.address
                          : '';
                      
                      // Get the cached avatar index
                      final avatarIndex = _getAvatarIndex(contact);

                       Widget avatar;
                      if (contact.photo != null && contact.photo!.isNotEmpty) {
                        avatar = CircleAvatar(
                          backgroundImage: MemoryImage(contact.photo!),
                          radius: 24,
                        );
                      } else {
                        avatar = CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.transparent,
                          backgroundImage: AssetImage('assets/contact-icons/$avatarIndex.png'),
                          child: Text(
                                  contact.displayName.isNotEmpty?_getContactInitials(contact.displayName).toUpperCase():'',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                )
                        );
                      }
                      
                      return ListTile(
                        leading: avatar,
                        title: Text(
                          contact.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xff3CB3E9) : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          [primaryPhone, primaryEmail]
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected 
                                ? const Color(0xff3CB3E9).withOpacity(0.8)
                                : Colors.grey[600],
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xff3CB3E9))
                            : null,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _tempSelected.remove(contact);
                            } else {
                              _tempSelected.add(contact);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(0.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _tempSelected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _tempSelected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff3CB3E9),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Import (${_tempSelected.length})',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
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