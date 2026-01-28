// lib/screens/contacts/import_contacts_screen.dart
import 'dart:io';
// import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/models/user.dart';
import 'package:nudge/screens/dashboard/dashboard_screen.dart';
// import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
// import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/contact_sync_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class ImportContactsScreen extends StatefulWidget {
  final List<SocialGroup>? groups;
  final bool isOnboarding;
  
  const ImportContactsScreen({
    super.key, 
    this.groups,
    this.isOnboarding = false
  });

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
  late List<SocialGroup> _availableGroups = [];
  bool _isOnboarding = false;
  late ThemeProvider globalThemeProvider;

  void _showSettingsDialog(String message, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        backgroundColor: themeProvider.getSurfaceColor(context),
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

  Future<void> _importDeviceContacts(ThemeProvider themeProvider) async {
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
      // Check if we have groups from arguments, otherwise fetch from API
      List<SocialGroup> groupsForSelection;
      
      if (_availableGroups.isNotEmpty) {
        groupsForSelection = _availableGroups;
      } else {
        print('No groups from arguments, fetching from API');
        User thisUser = await apiService.getUser();
        var userGroups = thisUser.groups;
        groupsForSelection = [];
        
        if (userGroups != null && userGroups.isNotEmpty) {
          for (int i = 0; i < userGroups.length; i++) {
            groupsForSelection.add(SocialGroup.fromMap(userGroups[i]));
          }
        } else {
          groupsForSelection = _createDefaultGroups();
        }
      }
      
      final SocialGroup? selectedGroup = await _showGroupSelectionDialog(groupsForSelection, themeProvider);
      if (selectedGroup == null) {
        setState(() {
          _isImporting = false;
          _statusMessage = '';
        });
        return;
      }

      final result = await syncService.importDeviceContacts(
        limit: _selectedQuantity,
        useSmartFilter: _useSmartFilter,
        group: selectedGroup,
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
        _showSettingsDialog(result['message'], themeProvider);
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
          
          Navigator.pop(context, importedContacts);
        } else {
          setState(() {
            _statusMessage =
                'Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!';
          });

          final importedContacts = await apiService.getAllContacts();
          final recentlyImportedContacts = importedContacts
              .where((contact) => contact.socialGroups.contains(selectedGroup.name))
              .toList();
          List<String> importedContactIds = [];
          recentlyImportedContacts.map((contact){
            importedContactIds.add(contact.id);
          });
          
          // CONDITIONALLY SCHEDULE NUDGES
          if (!_isOnboarding && recentlyImportedContacts.isNotEmpty) {
            await apiService.scheduleNudgesForContacts(contactIds: importedContactIds);
          }
          
          Navigator.pop(context, recentlyImportedContacts);

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
      
      Navigator.pop(context, []);
    }
  }

  Future<SocialGroup?> _showGroupSelectionDialog(List<SocialGroup> groupsForSelection, ThemeProvider themeProvider) async {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (groupsForSelection.isEmpty) {
      groupsForSelection = _createDefaultGroups();
    }
    
    // Show dialog for group selection
    return await showDialog<SocialGroup>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Group'),
        backgroundColor: themeProvider.getSurfaceColor(context),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: groupsForSelection.length,
            itemBuilder: (context, index) {
              final group = groupsForSelection[index];
              return Card(
                color: themeProvider.getCardColor(context),
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
                  title: Text(group.name, style: TextStyle(color: themeProvider.getTextPrimaryColor(context))),
                  subtitle: Text(
                    FrequencyPeriodMapper.getConversationalChoice(group.frequency, group.period),
                    style: TextStyle(color: themeProvider.getTextSecondaryColor(context)),
                  ),
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

  Future<void> _pickContactsAndImport(ThemeProvider themeProvider) async {
    // First, get the group selection
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    print('stage 1');
    
    List<SocialGroup> groupsForSelection;
    
    if (_availableGroups.isNotEmpty) {
      // Use groups passed from onboarding
      groupsForSelection = _availableGroups;
    } else {
      // Fallback: get groups from API
      try {
        User thisUser = await apiService.getUser();
        var userGroups = thisUser.groups;
        groupsForSelection = [];
        
        if (userGroups != null && userGroups.isNotEmpty) {
          for (int i = 0; i < userGroups.length; i++) {
            groupsForSelection.add(SocialGroup.fromMap(userGroups[i]));
          }
        } else {
          groupsForSelection = _createDefaultGroups();
        }
      } catch (e) {
        groupsForSelection = _createDefaultGroups();
      }
    }

    final SocialGroup? selectedGroup = await _showGroupSelectionDialog(groupsForSelection, themeProvider);
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group selection cancelled')),
      );
      return;
    }

    // Now check permission and get contacts
    final permissionOk = await fContacts.FlutterContacts.requestPermission();
    if (!permissionOk) {
      _showSettingsDialog('Contacts permission is required to pick contacts', themeProvider);
      return;
    }

    final contacts = await fContacts.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );

    final selectedContacts = await Navigator.of(context).push<List<fContacts.Contact>>(
      MaterialPageRoute(
        builder: (context) => _FullScreenContactPicker(
          contacts: contacts,
          selectedGroup: selectedGroup, // Pass the selected group to the picker
        ),
        fullscreenDialog: true,
      ),
    );

    if (selectedContacts == null || selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts selected')),
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

      List<String> importedContactIds = [];
      recentlyImportedContacts.map((contact){
        importedContactIds.add(contact.id);
      });
      
      // CONDITIONALLY SCHEDULE NUDGES
      if (_isOnboarding == false && recentlyImportedContacts.isNotEmpty) {
        await apiService.scheduleNudgesForContacts(contactIds: importedContactIds);
      }

      Navigator.pop(context, recentlyImportedContacts);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!'),
        ),
      );
    } else {
      setState(() {
        _statusMessage = 'Import failed: ${result['message']}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import contacts: ${result['message']}')),
      );
    }
  }

  // Add this method to create default groups when none are available
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

  String _getQuantityLabel(int quantity) {
    return quantity == 0 ? 'All Contacts' : 'First $quantity Contacts';
  }

  @override
  void initState() {
    super.initState();
    // For iOS, immediately open the contact picker
     _getArgumentsFromRoute();
    //  themeProvider = Provider.of<ThemeProvider>(context);
    
    // For iOS, immediately open the contact picker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isIOS) {
        // Don't auto-open picker during onboarding
        if (!_isOnboarding) {
          _pickContactsAndImport(globalThemeProvider);
        }
      }
    });
  }

  void _getArgumentsFromRoute() {
    _availableGroups = widget.groups as List<SocialGroup>;
     _isOnboarding = widget.isOnboarding;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    globalThemeProvider = themeProvider;
    var size = MediaQuery.of(context).size;
    
    // For iOS, show a simplified screen or directly open picker
    if (Platform.isIOS) {
      return _buildIOSVersion(themeProvider);
    }
    
    // For Android, show the full import options
    return _buildAndroidVersion(size, themeProvider);
  }

  Widget _buildIOSVersion(ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
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
        iconTheme: IconThemeData(color: AppTheme.primaryColor),
        backgroundColor: themeProvider.getSurfaceColor(context),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 50),
        child: FeedbackFloatingButton(),
      ),
      body: Container(
        color: themeProvider.getBackgroundColor(context),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.contacts,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'IMPORT YOUR CONTACTS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.getTextPrimaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Select contacts from your device to import into Nudge',
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.getTextSecondaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Import button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _isImporting ? null : _pickContactsAndImport(themeProvider);
                  }, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
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
                    side: BorderSide(color: themeProvider.getTextHintColor(context)),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, color: themeProvider.getTextSecondaryColor(context)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAndroidVersion(Size size, ThemeProvider themeProvider) {
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
        iconTheme: IconThemeData(color: AppTheme.primaryColor),
        backgroundColor: themeProvider.getSurfaceColor(context),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 50),
        child: FeedbackFloatingButton(),
      ),
      body: Container(
        color: themeProvider.getBackgroundColor(context),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            children: [
              Text(
                'IMPORT YOUR CONTACTS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Easily import your existing contacts to get started with Nudge',
                style: TextStyle(fontSize: 16, color: themeProvider.getTextSecondaryColor(context), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),

              // Import Options Card - Android only
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: themeProvider.getCardColor(context),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMPORT OPTIONS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.getTextSecondaryColor(context)),
                      ),
                      const SizedBox(height: 16),

                      // Quantity Selection - Android only
                      Text(
                        'How many contacts would you like to import?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: themeProvider.getTextPrimaryColor(context)),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quantityOptions.map((quantity) {
                          return FilterChip(
                            label: Text(_getQuantityLabel(quantity), style: TextStyle(
                              color: _selectedQuantity == quantity
                                  ? AppTheme.primaryColor
                                  : themeProvider.getTextPrimaryColor(context),
                              fontWeight: _selectedQuantity == quantity
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                            selected: _selectedQuantity == quantity,
                            onSelected: (selected) {
                              setState(() {
                                _selectedQuantity = selected ? quantity : 0;
                              });
                            },
                            backgroundColor: themeProvider.getBackgroundColor(context),
                            selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                            checkmarkColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: themeProvider.getTextHintColor(context)),
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
                            activeColor: AppTheme.primaryColor,
                            inactiveTrackColor: themeProvider.getTextHintColor(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SMART FILTER',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeProvider.getTextSecondaryColor(context)),
                                ),
                                Text(
                                  'Prioritize contacts you interact with most',
                                  style: TextStyle(fontSize: 14, color: themeProvider.getTextSecondaryColor(context)),
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
                              onPressed: () {
                                _isImporting ? null : _importDeviceContacts(themeProvider);
                              } ,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
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
                              onPressed: () {
                                _isImporting ? null : _pickContactsAndImport(themeProvider);
                              }, 
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: AppTheme.primaryColor),
                              ),
                              icon: const Padding(
                                padding: EdgeInsets.only(left: 5),
                                child: Icon(Icons.group_add, color: AppTheme.primaryColor),
                              ),
                              label: const Text(
                                'Pick & Import Selected',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.primaryColor,
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
                  color: themeProvider.getCardColor(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Progress',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context)),
                        ),
                        const SizedBox(height: 16),

                        LinearProgressIndicator(
                          value: _totalCount > 0 ? _processedCount / _totalCount : 0,
                          backgroundColor: themeProvider.getBackgroundColor(context),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          borderRadius: BorderRadius.circular(4),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _statusMessage,
                              style: TextStyle(fontSize: 14, color: themeProvider.getTextPrimaryColor(context)),
                            ),
                            Text(
                              '$_processedCount/$_totalCount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.getTextPrimaryColor(context),
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
                  color: Colors.green[themeProvider.isDarkMode ? 900 : 50],
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
                                  color: Colors.green[themeProvider.isDarkMode ? 300 : 800],
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
                color: themeProvider.getCardColor(context),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HOW IT WORKS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.getTextSecondaryColor(context)),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: Icon(Icons.filter_list, color: AppTheme.primaryColor),
                        title: Text('Smart Filter', style: TextStyle(fontWeight: FontWeight.w800, color: themeProvider.getTextPrimaryColor(context))),
                        subtitle: Text('Prioritizes contacts based on your interaction frequency', 
                          style: TextStyle(color: themeProvider.getTextSecondaryColor(context))),
                      ),
                      ListTile(
                        leading: Icon(Icons.group, color: AppTheme.primaryColor),
                        title: Text('Customizable Quantity', style: TextStyle(fontWeight: FontWeight.w800, color: themeProvider.getTextPrimaryColor(context))),
                        subtitle: Text('Choose how many contacts to import based on your needs', 
                          style: TextStyle(color: themeProvider.getTextSecondaryColor(context))),
                      ),
                      ListTile(
                        leading: Icon(Icons.security, color: AppTheme.primaryColor),
                        title: Text('Privacy First', style: TextStyle(fontWeight: FontWeight.w800, color: themeProvider.getTextPrimaryColor(context))),
                        subtitle: Text('Your contacts are only stored on your device and our secure servers', 
                          style: TextStyle(color: themeProvider.getTextSecondaryColor(context))),
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

/// Full-screen contact picker widget for selecting contacts to import
class _FullScreenContactPicker extends StatefulWidget {
  final List<fContacts.Contact> contacts;
  final SocialGroup? selectedGroup; // Add this parameter

  const _FullScreenContactPicker({
    required this.contacts,
    this.selectedGroup, // Add this parameter
  });

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

   void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SELECT CONTACTS',
              style: TextStyle(
                color: themeProvider.getTextPrimaryColor(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.selectedGroup != null)
              Text(
                'for ${widget.selectedGroup!.name}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: themeProvider.getSurfaceColor(context),
        actions: [
          IconButton(
            icon: Icon(Icons.select_all, color: themeProvider.getTextPrimaryColor(context)),
            tooltip: 'Select all',
            onPressed: _selectAllFiltered,
          ),
          IconButton(
            icon: Icon(Icons.clear, color: themeProvider.getTextPrimaryColor(context)),
            tooltip: 'Clear selection',
            onPressed: _clearFilteredSelection,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              '${_tempSelected.length}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.getTextPrimaryColor(context)),
            ),
          ),
        ],
      ),
      body: Container(
        color: themeProvider.getBackgroundColor(context),
        child: Column(
          children: [
            // Group info banner (if group is selected)
            if (widget.selectedGroup != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.primaryColor.withOpacity(0.1),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Color(int.parse(widget.selectedGroup!.colorCode.replaceAll('#', '0xFF'))),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contacts will be added to: ${widget.selectedGroup!.name}',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: themeProvider.getTextPrimaryColor(context)),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: themeProvider.getTextSecondaryColor(context)),
                  hintText: 'Search by name, phone, or email',
                  hintStyle: TextStyle(color: themeProvider.getTextHintColor(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeProvider.getTextHintColor(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeProvider.getTextHintColor(context)),
                  ),
                  filled: true,
                  fillColor: themeProvider.getCardColor(context),
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
                    style: TextStyle(fontSize: 12, color: themeProvider.getTextSecondaryColor(context)),
                  ),
                  Text(
                    'Selected: ${_tempSelected.length}',
                    style: TextStyle(fontSize: 12, color: themeProvider.getTextSecondaryColor(context)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Divider
            Divider(height: 1, color: themeProvider.getTextHintColor(context)),
            
            // Contacts list
            Expanded(
              child: _filteredContacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off, size: 64, color: themeProvider.getTextSecondaryColor(context)),
                          const SizedBox(height: 16),
                          Text(
                            'No contacts found',
                            style: TextStyle(fontSize: 18, color: themeProvider.getTextSecondaryColor(context)),
                          ),
                          if (_searchController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Try a different search term',
                                style: TextStyle(fontSize: 14, color: themeProvider.getTextHintColor(context)),
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
                              contact.displayName.isNotEmpty ? _getContactInitials(contact.displayName).toUpperCase() : '',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          );
                        }
                        
                        return Container(
                          color: isSelected 
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          child: ListTile(
                            leading: avatar,
                            title: Text(
                              contact.displayName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.primaryColor : themeProvider.getTextPrimaryColor(context),
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
                                    ? AppTheme.primaryColor.withOpacity(0.8)
                                    : themeProvider.getTextSecondaryColor(context),
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: themeProvider.getSurfaceColor(context),
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
                    side: BorderSide(color: themeProvider.getTextHintColor(context)),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, color: themeProvider.getTextSecondaryColor(context)),
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
                    backgroundColor: AppTheme.primaryColor,
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
    ));
  }
}