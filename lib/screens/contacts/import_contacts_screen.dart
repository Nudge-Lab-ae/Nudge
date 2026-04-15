// lib/screens/contacts/import_contacts_screen.dart
// import 'dart:convert';
import 'dart:io';
// import 'dart:typed_data';
// import 'dart:typed_data';

// import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/models/social_group.dart';
import 'package:nudge/models/user.dart';
import 'package:nudge/providers/feedback_provider.dart';
// import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/services/message_service.dart';
// import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:nudge/widgets/gradient_text.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fContacts;
// import 'package:flutter_contacts_stack/flutter_contacts_stack.dart' as contacts_stack;
import '../../providers/theme_provider.dart';
// import '../../theme/app_theme.dart';
import '../../services/contact_sync_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class ImportContactsScreen extends StatefulWidget {
  final List<SocialGroup>? groups;
  final bool isOnboarding;
  final SocialGroup? preSelectedGroup;
  
  const ImportContactsScreen({
    super.key, 
    this.groups,
    this.isOnboarding = false,
    this.preSelectedGroup,
  });

  @override
  State<ImportContactsScreen> createState() => _ImportContactsScreenState();
}

class _ImportContactsScreenState extends State<ImportContactsScreen> {
  bool _isImporting = false;
  bool _isFetchingContacts = false; // true while permission+contacts load before picker opens
  // int _processedCount = 0;
  // int _totalCount = 0;
  // String _statusMessage = '';
  // int _selectedQuantity = 50;
  // bool _useSmartFilter = true;
  // final List<int> _quantityOptions = [25, 50, 100, 150];
  late List<SocialGroup> _availableGroups = [];
  bool _isOnboarding = false;
  late ThemeProvider globalThemeProvider;
  SocialGroup? _preSelectedGroup;
  late FeedbackFloatingButtonController _fabController;

  void _showSettingsDialog(String message, ThemeProvider themeProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
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

  // Future<void> _importDeviceContacts(ThemeProvider themeProvider) async {
  //   setState(() {
  //     _isImporting = true;
  //     _processedCount = 0;
  //     _totalCount = 0;
  //     _statusMessage = 'Checking for existing contacts...';
  //   });

  //   final authService = Provider.of<AuthService>(context, listen: false);
  //   final apiService = Provider.of<ApiService>(context, listen: false);
  //   final user = authService.currentUser;
  //   if (user == null) {
  //     setState(() => _isImporting = false);
  //     return;
  //   }

  //   final syncService = ContactSyncService(apiService: apiService);

  //   try {
  //     // Check if we have groups from arguments, otherwise fetch from API
  //     // List<SocialGroup> groupsForSelection;
      
  //     SocialGroup? selectedGroup;
      
  //     if (_preSelectedGroup != null) {
  //       // Use the pre-selected group
  //       selectedGroup = _preSelectedGroup;
  //     } else {
  //       // Original logic: show group selection dialog
  //       List<SocialGroup> groupsForSelection;
        
  //       if (_availableGroups.isNotEmpty) {
  //         groupsForSelection = _availableGroups;
  //       } else {
  //         //print('No groups from arguments, fetching from API');
  //         User thisUser = await apiService.getUser();
  //         var userGroups = thisUser.groups;
  //         groupsForSelection = [];
          
  //         if (userGroups != null && userGroups.isNotEmpty) {
  //           for (int i = 0; i < userGroups.length; i++) {
  //             groupsForSelection.add(SocialGroup.fromMap(userGroups[i]));
  //           }
  //         } else {
  //           groupsForSelection = _createDefaultGroups();
  //         }
  //       }
        
  //       selectedGroup = await _showGroupSelectionDialog(groupsForSelection, themeProvider);
  //     }

  //     if (selectedGroup == null) {
  //       setState(() {
  //         _isImporting = false;
  //         _statusMessage = '';
  //       });
  //       return;
  //     }

  //     final result = await syncService.importDeviceContacts(
  //       limit: _selectedQuantity,
  //       useSmartFilter: _useSmartFilter,
  //       group: selectedGroup,
  //       onProgress: (processed, total) {
  //         setState(() {
  //           _processedCount = processed;
  //           _totalCount = total;
  //           _statusMessage = 'Processing $processed of $total contacts...';
  //         });
  //       },
  //     );

  //     setState(() => _isImporting = false);
  //     final importedContacts = await apiService.getAllContacts();

  //     if (result['needsSettings'] == true) {
  //       _showSettingsDialog(result['message'], themeProvider);
  //       return;
  //     }

  //     if (result['success'] == true) {
  //       if (result['importedCount'] == 0) {
  //         setState(() {
  //           _statusMessage =
  //               'No new contacts to import - all contacts already exist in Nudge';
  //         });

  //         // ScaffoldMessenger.of(context).showSnackBar(
  //         //   const SnackBar(content: Text('All contacts already imported')),
  //         // );

  //          TopMessageService().showMessage(
  //           context: context,
  //           message: 'All Contacts already imported.',
  //           backgroundColor: Colors.blueGrey,
  //           icon: Icons.info,
  //         );
          
  //         // Different navigation based on source
  //         if (_isOnboarding) {
  //           // Onboarding: just return the contacts
  //           Navigator.pop(context, importedContacts);
  //         } else if (_preSelectedGroup != null) {
  //           // From group card: return to group details
  //           Navigator.pop(context, importedContacts);
  //         } else {
  //           // From FAB: return with confetti flag
  //           Navigator.pop(context, {'showConfetti': true, 'contacts': importedContacts});
  //         }
  //       } else {
  //         setState(() {
  //           _statusMessage =
  //               'Successfully imported ${result['importedCount']} contacts to ${selectedGroup!.name}!';
  //         });

  //         final importedContacts = await apiService.getAllContacts();
  //         final recentlyImportedContacts = result['theImportedContacts'];
  //         List<String> importedContactIds = [];
  //         for (int i =0; i<recentlyImportedContacts.length; i++) {
  //           Contact indexContact = recentlyImportedContacts[i];
  //           Contact thisContact = importedContacts.where((contact) => contact.name == indexContact.name).first;
  //           String contactId = thisContact.id;
  //           importedContactIds.add(contactId);
  //           //print(contactId); //print(recentlyImportedContacts[i].name); //print(thisContact.toMap());
  //           importedContacts.add(recentlyImportedContacts[i]);
  //         }
  //         //print('Imported contact ids: $importedContactIds');
  //         //print('Imported contacts are: $importedContacts');
          
  //         // CONDITIONALLY SCHEDULE NUDGES
  //         if (!_isOnboarding && recentlyImportedContacts.isNotEmpty) {
  //           apiService.scheduleNudgesForContacts(contactIds: importedContactIds);
  //           apiService.scheduleEventNotifications(recentlyImportedContacts);
  //         }
          
  //         // Different navigation based on source
  //         if (_isOnboarding) {
  //           // Onboarding: just return the contacts
  //           Navigator.pop(context, recentlyImportedContacts);
  //         } else if (_preSelectedGroup != null) {
  //           // From group card: return to group details
  //           Navigator.pop(context, recentlyImportedContacts);
  //         } else {
  //           // From FAB: return with confetti flag
  //           Navigator.pop(context, {'showConfetti': true, 'contacts': recentlyImportedContacts});
  //         }

  //         // Flushbar(
  //         //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
  //         //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
  //         //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
  //         //   messageText: Center(
  //         //       child: Text( 'Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
  //         //           color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
  //         // ).show(context);

  //         TopMessageService().showMessage(
  //           context: context,
  //           message: 'Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!',
  //           backgroundColor: AppColors.success,
  //           icon: Icons.check,
  //         );

  //       }
  //     } else {
  //       setState(() {
  //         _statusMessage = 'Import failed: ${result['message']}';
  //       });

  //       // ScaffoldMessenger.of(context).showSnackBar(
  //       //   SnackBar(content: Text('Failed to import contacts: ${result['message']}')),
  //       // );

  //        TopMessageService().showMessage(
  //           context: context,
  //           message: 'Failed to import contacts: ${result['message']})',
  //           backgroundColor: Theme.of(context).colorScheme.tertiary,
  //           icon: Icons.error,
  //         );
        
  //       Navigator.pop(context, []);
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isImporting = false;
  //       _statusMessage = 'Error: $e';
  //     });

  //     // ScaffoldMessenger.of(context).showSnackBar(
  //     //   SnackBar(content: Text('Failed to import contacts: $e')),
  //     // );

  //      TopMessageService().showMessage(
  //           context: context,
  //           message: 'Failed to import contact: $e',
  //           backgroundColor: Theme.of(context).colorScheme.tertiary,
  //           icon: Icons.error,
  //         );
      
  //     Navigator.pop(context, []);
  //   }
  // }

  Future<SocialGroup?> _showGroupSelectionDialog(List<SocialGroup> groupsForSelection, ThemeProvider themeProvider) async {
    if (groupsForSelection.isEmpty) {
      groupsForSelection = _createDefaultGroups();
    }

    return await showModalBottomSheet<SocialGroup>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = themeProvider.isDarkMode;
        final scheme = Theme.of(context).colorScheme;
        final cardBg = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
        final bg     = isDark ? AppColors.darkSurfaceContainerLow  : const Color(0xFFF5F3F0);
        final textP  = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
        final textS  = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(9999)),
              ),
              const SizedBox(height: 8),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Choose a Group',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20, fontWeight: FontWeight.w800, color: textP)),
                      const SizedBox(height: 2),
                      Text('Contacts will be added to this group',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: textS)),
                    ]),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainerHighest
                              : const Color(0xFFECE7E2),
                          shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded, size: 16, color: textS),
                      ),
                    ),
                  ],
                ),
              ),

              // Group list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: groupsForSelection.length,
                  itemBuilder: (context, index) {
                    final group = groupsForSelection[index];
                    Color groupColor;
                    try {
                      groupColor = Color(
                          int.parse(group.colorCode.replaceAll('#', '0xFF')));
                    } catch (_) {
                      groupColor = AppColors.lightPrimary;
                    }

                    return GestureDetector(
                      onTap: () => Navigator.pop(context, group),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(
                                isDark ? 0.15 : 0.05),
                            blurRadius: 10, offset: const Offset(0, 2))],
                        ),
                        child: Row(children: [
                          // Colour dot + emoji or initial
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: groupColor.withOpacity(0.15),
                              shape: BoxShape.circle),
                            child: Center(
                              child: group.emoji.isNotEmpty
                                  ? Text(group.emoji,
                                      style: const TextStyle(fontSize: 20))
                                  : Text(
                                      group.name.isNotEmpty
                                          ? group.name[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: groupColor)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Name + frequency
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: textP)),
                              const SizedBox(height: 2),
                              Text(
                                FrequencyPeriodMapper.getConversationalChoice(
                                    group.frequency, group.period),
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13, color: textS)),
                            ],
                          )),
                          // Chevron
                          Icon(Icons.chevron_right_rounded,
                              color: textS, size: 20),
                        ]),
                      ),
                    );
                  },
                ),
              ),

              // Cancel text
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Center(
                    child: Text('Cancel',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15, fontWeight: FontWeight.w500,
                        color: textS)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Updated _pickContactsAndImport method using flutter_contacts for both platforms
  Future<void> _pickContactsAndImport(ThemeProvider themeProvider) async {
    // First, get the group selection
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    //print('stage 1');
    
    SocialGroup? selectedGroup;
    
    if (_preSelectedGroup != null) {
      selectedGroup = _preSelectedGroup;
    } else {
      List<SocialGroup> groupsForSelection;
      
      if (_availableGroups.isNotEmpty) {
        groupsForSelection = _availableGroups;
      } else {
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

      selectedGroup = await _showGroupSelectionDialog(groupsForSelection, themeProvider);
    }
    
    if (selectedGroup == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Group selection cancelled')),
      // );
       TopMessageService().showMessage(
            context: context,
            message: 'Group selection cacelled.',
            backgroundColor: Colors.blueGrey,
            icon: Icons.info,
          );
      return;
    }

    // Show loading indicator
    setState(() {
      // _statusMessage = 'Loading contacts...';
    });

    // Check and request permission
    //print('Checking contacts permission...');
    bool permissionOk = await fContacts.FlutterContacts.requestPermission();
    
    if (!permissionOk) {
      // For iOS, check detailed status
      if (Platform.isIOS) {
        final status = await Permission.contacts.status;
        //print('iOS contacts permission status: $status');
        
        if (status.isPermanentlyDenied) {
          _showSettingsDialog('Contacts access is disabled. Please enable it in Settings to import your contacts.', themeProvider);
          return;
        } else if (status.isDenied) {
          // Try requesting again
          permissionOk = await Permission.contacts.request().isGranted;
        }
      }
      
      if (!permissionOk) {
        _showSettingsDialog('Contacts permission is required to pick contacts', themeProvider);
        return;
      }
    }

    // Get contacts with ALL properties (including events for birthdays)
    //print('Fetching contacts with full properties...');
    setState(() => _isFetchingContacts = true);
    List<fContacts.Contact> contacts = [];
    
    try {
      contacts = await fContacts.FlutterContacts.getContacts(
        withProperties: true,  // This includes phones, emails, AND EVENTS
        withPhoto: true,       // Get high-res photos
        withThumbnail: true,   // Get thumbnails too
      );
      //print('Successfully retrieved ${contacts.length} contacts');
      
      // Debug: Check if birthdays are present
      
    } catch (e) {
      //print('Error getting contacts: $e');
      //print('Stack trace: $stack');
      
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to load contacts: ${e.toString()}'),
      //     duration: const Duration(seconds: 3),
      //   ),
      // );
      setState(() => _isFetchingContacts = false);
      TopMessageService().showMessage(
          context: context,
          message: 'Failed to load contacts: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          icon: Icons.error,
        );
      return;
    }

    if (contacts.isEmpty) {
      setState(() {
        // _statusMessage = '';
      });
      
      if (Platform.isIOS) {
        var isSimulator = Platform.isIOS && 
            (Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
            Platform.environment['SIMULATOR_RUNTIME_VERSION'] != null);
        
        if (isSimulator) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('iOS Simulator detected. Please ensure you have added contacts in the Simulator\'s Contacts app and granted permission.'),
          //     duration: Duration(seconds: 5),
          //   ),
          // );
          TopMessageService().showMessage(
                  context: context,
                  message: 'iOS Simulator detected. Please ensure you have added contacts in the Simulator\'s Contacts app and granted permission.',
                  backgroundColor: AppColors.success,
                  icon: Icons.check,
                );
        } else {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('No contacts found on device'),
          //     duration: Duration(seconds: 3),
          //   ),
          // );
          TopMessageService().showMessage(
                  context: context,
                  message: 'No contacts found on device.',
                  backgroundColor: AppColors.success,
                  icon: Icons.check,
                );
        }
      }
      return;
    }

    // Filter out invalid contacts
    final validContacts = contacts.where((contact) {
      final hasName = contact.displayName.isNotEmpty || 
                    contact.name.first.isNotEmpty || 
                    contact.name.last.isNotEmpty;
      final hasPhone = contact.phones.isNotEmpty;
      final hasEmail = contact.emails.isNotEmpty;
      
      return hasName || hasPhone || hasEmail;
    }).toList();
    
    //print('Valid contacts after filtering: ${validContacts.length}');

    final existingContacts = await apiService.getAllContacts();
    //print('Existing contacts retrieved: ${existingContacts.length}');

    setState(() => _isFetchingContacts = false);
    final selectedContacts = await Navigator.of(context).push<List<fContacts.Contact>>(
      MaterialPageRoute(
        builder: (context) => _FullScreenContactPicker(
          contacts: validContacts,
          existingContacts: existingContacts,
          selectedGroup: selectedGroup,
        ),
        fullscreenDialog: true,
      ),
    );

    if (selectedContacts == null || selectedContacts.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('No contacts selected')),
      // );
      TopMessageService().showMessage(
        context: context,
        message: 'No contacts selected.',
        backgroundColor: Colors.blueGrey,
        icon: Icons.info,
      );
      return;
    }

    final user = authService.currentUser;
    if (user == null) return;

    final syncService = ContactSyncService(apiService: apiService);

    setState(() {
      _isImporting = true;
      // _processedCount = 0;
      // _totalCount = selectedContacts.length;
      // _statusMessage = 'Importing selected contacts to ${selectedGroup!.name}...';
    });

    final result = await syncService.importFromContactPicker(
      pickedContacts: selectedContacts,
      groupId: selectedGroup.name,
      onProgress: (processed, total) {
        setState(() {
          // _processedCount = processed;
          // _totalCount = total;
          // _statusMessage = 'Processing $processed of $total contacts...';
        });
      },
    );

    setState(() => _isImporting = false);
    //print('The result is: $result');
    
    if (result['success'] == true) {
      setState(() {
        // _statusMessage =
        //     'Successfully imported ${result['importedCount']} contacts to ${selectedGroup!.name}!';
      });

      final importedContacts = await apiService.getAllContacts();
      final recentlyImportedContacts = result['theImportedContacts'];

      List<String> importedContactIds = [];
      
      for (int i =0; i<recentlyImportedContacts.length; i++) {
        Contact indexContact = recentlyImportedContacts[i];
        Contact thisContact = importedContacts.where((contact) => contact.name == indexContact.name).first;
        String contactId = thisContact.id;
        importedContactIds.add(contactId);
        //print(contactId); //print(recentlyImportedContacts[i].name); //print(thisContact.toMap());
        importedContacts.add(recentlyImportedContacts[i]);
      }
      //print('Imported contact ids: $importedContactIds');
      //print('Imported contacts are: $importedContacts');
      
      // CONDITIONALLY SCHEDULE NUDGES
      if (_isOnboarding == false && recentlyImportedContacts.isNotEmpty) {
        apiService.scheduleNudgesForContacts(contactIds: importedContactIds);
        apiService.scheduleEventNotifications(recentlyImportedContacts);
      }

      // Different navigation based on source
      if (_isOnboarding) {
        // Onboarding: just return the contacts
        Navigator.pop(context, recentlyImportedContacts);
      } else if (_preSelectedGroup != null) {
        // From group card: return to group details
        Navigator.pop(context, recentlyImportedContacts);
      } else {
        // From FAB: return with confetti flag
        Navigator.pop(context, {'showConfetti': true, 'contacts': recentlyImportedContacts});
      }

      // Flushbar(
      //       padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
      //       flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      //       forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
      //       messageText: Center(
      //           child: Text( 'Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!', style: TextStyle(fontFamily: GoogleFonts.beVietnamPro().fontFamily, fontSize: 14,
      //               color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w400),)),
      //     ).show(context);

      TopMessageService().showMessage(
            context: context,
            message: 'Successfully imported ${result['importedCount']} contacts to ${selectedGroup.name}!',
            backgroundColor: AppColors.success,
            icon: Icons.check,
          );
    } else {
      setState(() {
        // _statusMessage = 'Import failed: ${result['message']}';
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to import contacts: ${result['message']}')),
      // );

      TopMessageService().showMessage(
            context: context,
            message: 'Failed to import contacts: ${result['message']}',
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            icon: Icons.error,
          );
    }
  }
  
  String normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Handle iOS-specific formatting issues
    if (Platform.isIOS) {
      // iOS often includes country code without the plus sign
      // Common country codes to handle (US/CA: 1, UK: 44, etc.)
      
      // If number starts with 1 and is exactly 11 digits (US/Canada with country code)
      if (digits.length == 11 && digits.startsWith('1')) {
        // Keep as is, but also create a version without country code for comparison
        return digits;
      }
      
      // If number is 10 digits (US/Canada without country code)
      if (digits.length == 10) {
        // Also consider the version with US country code
        return digits;
      }
      
      // For other lengths, return as is
      return digits;
    }
    
    return digits;
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

  // String _getQuantityLabel(int quantity) {
  //   return quantity == 0 ? 'All Contacts' : 'First $quantity Contacts';
  // }

  @override
  void initState() {
    super.initState();
    // For iOS, immediately open the contact picker
     _getArgumentsFromRoute();
    //  themeProvider = Provider.of<ThemeProvider>(context);
    
    // For iOS, immediately open the contact picker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // if (Platform.isIOS) {
      //   // Don't auto-open picker during onboarding
      //   if (!_isOnboarding) {
      //     _pickContactsAndImport(globalThemeProvider);
      //   }
      // }
      if (!_isOnboarding) {
        _pickContactsAndImport(globalThemeProvider);
      }
    });
     _fabController = FeedbackFloatingButtonController();
  }

   @override
  void dispose() {
    _fabController = FeedbackFloatingButtonController();
    super.dispose();
  }

  void _getArgumentsFromRoute() {
    if (widget.groups!=null) {
      _availableGroups = widget.groups as List<SocialGroup>;
    }
     _isOnboarding = widget.isOnboarding;
    _preSelectedGroup = widget.preSelectedGroup; // Get pre-selected group
    
    // If we have a pre-selected group, add it to available groups
    if (_preSelectedGroup != null && !_availableGroups.contains(_preSelectedGroup)) {
      _availableGroups = [_preSelectedGroup!];
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    globalThemeProvider = themeProvider;
    // var size = MediaQuery.of(context).size;
    final feedbackProvider = Provider.of<FeedbackProvider>(context);
    
    // For iOS, show a simplified screen or directly open picker
    if (Platform.isIOS) {
      return _buildIOSVersion(themeProvider, feedbackProvider);
    }
    
    // For Android, show the full import options
    return _buildIOSVersion(themeProvider, feedbackProvider);
    // return _buildAndroidVersion(size, themeProvider, feedbackProvider);
  }

  Widget _buildIOSVersion(ThemeProvider themeProvider, FeedbackProvider feedbackProvider) {
    // final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
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
      title: Column(
        children: [
         GradientText(
            text: 'NUDGE',
            style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 25),
            gradient: LinearGradient(
              colors: themeProvider.isDarkMode
                  ? AppColors.primaryGradientDark
                  : AppColors.primaryGradientLight,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          if (_preSelectedGroup != null)
            Text(
              'Import to ${_preSelectedGroup!.name}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.lightPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      iconTheme: themeProvider.isDarkMode?IconThemeData(color: const Color.fromARGB(255, 165, 141, 196)):IconThemeData(color: AppColors.lightPrimary),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    ),
            body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.contacts,
                size: 80,
                color: AppColors.lightPrimary,
              ),
              const SizedBox(height: 24),
              Text(
                'IMPORT YOUR CONTACTS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Select contacts from your device to import into Nudge',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Show a loading state while fetching contacts (between tapping
              // the button and the picker screen appearing), otherwise show
              // the normal import / cancel buttons.
              if (_isFetchingContacts) ...[
                const SizedBox(height: 8),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: AppColors.lightPrimary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Loading your contacts…',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                // Import button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _isImporting ? null : _pickContactsAndImport(themeProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isImporting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onInverseSurface,
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
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
                      _fabController.closeMenu();
                    },
                    child: Container(
                      color: Colors.transparent,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),
    ]
    ));
  }

  // Widget _buildAndroidVersion(Size size, ThemeProvider themeProvider, FeedbackProvider feedbackProvider) {
  //   return Scaffold(
  //     floatingActionButton: Padding(
  //       padding: EdgeInsets.only(bottom: 20),
  //       child: FeedbackFloatingButton(),
  //     ),
  //     body: Stack(
  //       children: [
  //         Scaffold(
  //           appBar: AppBar(
  //             title: Column(
  //               children: [
  //                 GradientText(
  //                   text: 'NUDGE',
  //                   style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
  //                   gradient: const LinearGradient(
  //                     colors: [AppColors.lightSecondary, AppColors.lightPrimary],
  //                     begin: Alignment.topCenter,
  //                     end: Alignment.bottomCenter,
  //                   ),
  //                 ),
  //                 if (_preSelectedGroup != null)
  //                   Text(
  //                     'Import to ${_preSelectedGroup!.name}',
  //                     style: TextStyle(
  //                       fontSize: 12,
  //                       color: AppColors.lightPrimary,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //               ],
  //             ),
  //             centerTitle: true,
  //             surfaceTintColor: Colors.transparent,
  //             iconTheme: IconThemeData(color: AppColors.lightPrimary),
  //             backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
  //           ),
  //           body: Container(
  //       color: Theme.of(context).scaffoldBackgroundColor,
  //       child: Padding(
  //         padding: const EdgeInsets.all(20.0),
  //         child: ListView(
  //           children: [
  //             Text(
  //               'IMPORT YOUR CONTACTS',
  //               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'Easily import your existing contacts to get started with Nudge',
  //               style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
  //             ),
  //             const SizedBox(height: 30),

  //             // Import Options Card - Android only
  //             Card(
  //               elevation: 4,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(16),
  //               ),
  //               color: Theme.of(context).colorScheme.onSurface,
  //               child: Padding(
  //                 padding: const EdgeInsets.all(16.0),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       'IMPORT OPTIONS',
  //                       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
  //                     ),
  //                     const SizedBox(height: 16),

  //                     // Quantity Selection - Android only
  //                     Text(
  //                       'How many contacts would you like to import?',
  //                       style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
  //                     ),
  //                     const SizedBox(height: 12),

  //                     Wrap(
  //                       spacing: 8,
  //                       runSpacing: 8,
  //                       children: _quantityOptions.map((quantity) {
  //                         return FilterChip(
  //                           label: Text(_getQuantityLabel(quantity), style: TextStyle(
  //                             color: _selectedQuantity == quantity
  //                                 ? AppColors.lightPrimary
  //                                 : Theme.of(context).colorScheme.onSurface,
  //                             fontWeight: _selectedQuantity == quantity
  //                                 ? FontWeight.bold
  //                                 : FontWeight.normal,
  //                           )),
  //                           selected: _selectedQuantity == quantity,
  //                           onSelected: (selected) {
  //                             setState(() {
  //                               _selectedQuantity = selected ? quantity : 0;
  //                             });
  //                           },
  //                           backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  //                           selectedColor: AppColors.lightPrimary.withOpacity(0.2),
  //                           checkmarkColor: AppColors.lightPrimary,
  //                           shape: RoundedRectangleBorder(
  //                             borderRadius: BorderRadius.circular(20),
  //                             side: BorderSide(color: Theme.of(context).colorScheme.outline),
  //                           ),
  //                         );
  //                       }).toList(),
  //                     ),

  //                     const SizedBox(height: 20),

  //                     // Smart Filter Option - Android only
  //                     Row(
  //                       children: [
  //                         Switch(
  //                           value: _useSmartFilter,
  //                           onChanged: (value) {
  //                             setState(() {
  //                               _useSmartFilter = value;
  //                             });
  //                           },
  //                           activeColor: AppColors.lightPrimary,
  //                           inactiveTrackColor: Theme.of(context).colorScheme.outline,
  //                         ),
  //                         const SizedBox(width: 8),
  //                         Expanded(
  //                           child: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               Text(
  //                                 'SMART FILTER',
  //                                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
  //                               ),
  //                               Text(
  //                                 'Prioritize contacts you interact with most',
  //                                 style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       ],
  //                     ),

  //                     const SizedBox(height: 16),

  //                     // Buttons: import device contacts + pick selected contacts
  //                     Row(
  //                       children: [
  //                         Expanded(
  //                           child: ElevatedButton(
  //                             onPressed: () {
  //                               _isImporting ? null : _importDeviceContacts(themeProvider);
  //                             } ,
  //                             style: ElevatedButton.styleFrom(
  //                               backgroundColor: AppColors.lightPrimary,
  //                               padding: const EdgeInsets.symmetric(vertical: 16),
  //                               shape: RoundedRectangleBorder(
  //                                 borderRadius: BorderRadius.circular(16),
  //                               ),
  //                             ),
  //                             child: _isImporting
  //                                 ? Row(
  //                                     mainAxisAlignment: MainAxisAlignment.center,
  //                                     children: [
  //                                       SizedBox(
  //                                         width: 20,
  //                                         height: 20,
  //                                         child: CircularProgressIndicator(
  //                                           color: Theme.of(context).colorScheme.onSurface,
  //                                           strokeWidth: 2,
  //                                         ),
  //                                       ),
  //                                       SizedBox(width: 12),
  //                                       Text('Importing...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
  //                                     ],
  //                                   )
  //                                 : const Text(
  //                                     'Start Import',
  //                                     style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
  //                                   ),
  //                           ),
  //                         ),
  //                         const SizedBox(width: 12),
  //                         Expanded(
  //                           child: OutlinedButton.icon(
  //                             onPressed: () {
  //                               _isImporting ? null : _pickContactsAndImport(themeProvider);
  //                             }, 
  //                             style: OutlinedButton.styleFrom(
  //                               padding: const EdgeInsets.symmetric(vertical: 16),
  //                               shape: RoundedRectangleBorder(
  //                                 borderRadius: BorderRadius.circular(16),
  //                               ),
  //                               side: BorderSide(color: AppColors.lightPrimary),
  //                             ),
  //                             icon: const Padding(
  //                               padding: EdgeInsets.only(left: 5),
  //                               child: Icon(Icons.group_add, color: AppColors.lightPrimary),
  //                             ),
  //                             label: const Text(
  //                               'Pick & Import Selected',
  //                               style: TextStyle(
  //                                 fontSize: 16,
  //                                 color: AppColors.lightPrimary,
  //                               ),
  //                             ),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),

  //             const SizedBox(height: 20),

  //             // Progress Section
  //             if (_isImporting) ...[
  //               Card(
  //                 elevation: 4,
  //                 shape: RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(16),
  //                 ),
  //                 color: Theme.of(context).colorScheme.onSurface,
  //                 child: Padding(
  //                   padding: const EdgeInsets.all(16.0),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'Import Progress',
  //                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
  //                       ),
  //                       const SizedBox(height: 16),

  //                       LinearProgressIndicator(
  //                         value: _totalCount > 0 ? _processedCount / _totalCount : 0,
  //                         backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  //                         valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lightPrimary),
  //                         borderRadius: BorderRadius.circular(8),
  //                       ),

  //                       const SizedBox(height: 12),

  //                       Row(
  //                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                         children: [
  //                           Text(
  //                             _statusMessage,
  //                             style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
  //                           ),
  //                           Text(
  //                             '$_processedCount/$_totalCount',
  //                             style: TextStyle(
  //                               fontSize: 14,
  //                               fontWeight: FontWeight.bold,
  //                               color: Theme.of(context).colorScheme.onSurface,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ],

  //             const SizedBox(height: 20),

  //             // Results Section
  //             if (!_isImporting && _statusMessage.isNotEmpty) ...[
  //               Card(
  //                 elevation: 4,
  //                 shape: RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(16),
  //                 ),
  //                 color: _statusMessage.contains('Successfully')
  //                         ?Colors.green[themeProvider.isDarkMode ? 900 : 50]
  //                         : _statusMessage.contains('failed') || _statusMessage.contains('Error')
  //                         ? Colors.white.withOpacity(themeProvider.isDarkMode?0.4:1.0)
  //                         : const Color.fromARGB(255, 195, 194, 194),
  //                 child: Padding(
  //                   padding: const EdgeInsets.all(16.0),
  //                   child: Row(
  //                     children: [
  //                       Icon(
  //                         _statusMessage.contains('Successfully')
  //                         ?Icons.check_circle
  //                         :_statusMessage.contains('failed') || _statusMessage.contains('Error')
  //                         ?Icons.error
  //                         :Icons.question_mark,
  //                         color: _statusMessage.contains('Successfully')
  //                         ?AppColors.success
  //                         :_statusMessage.contains('failed') || _statusMessage.contains('Error')
  //                         ? Theme.of(context).colorScheme.error
  //                         : Theme.of(context).colorScheme.outline,
  //                         size: 32,
  //                       ),
  //                       const SizedBox(width: 12),
  //                       Expanded(
  //                         child: Column(
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             Text(
  //                               _statusMessage.contains('Successfully')
  //                         ?'Import Successful'
  //                         : _statusMessage.contains('failed') || _statusMessage.contains('Error')
  //                         ?'Import Failed'
  //                         :'Import Status: ',
  //                               style: TextStyle(
  //                                 fontSize: 16,
  //                                 fontWeight: FontWeight.bold,
  //                                 color: _statusMessage.contains('Successfully')
  //                         ?AppColors.success
  //                         : _statusMessage.contains('failed') || _statusMessage.contains('Error')
  //                         ? Colors.white
  //                         : AppColors.lightOnSurface,
  //                               ),
  //                             ),
  //                             const SizedBox(height: 4),
  //                             Text(
  //                               _statusMessage,
  //                               style: TextStyle(
  //                                 color:_statusMessage.contains('Successfully')
  //                         ?AppColors.success
  //                         : _statusMessage.contains('failed') || _statusMessage.contains('Error')
  //                         ? Colors.white
  //                         : AppColors.lightOnSurface,
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ],

  //             const SizedBox(height: 20),

  //             // Information Section - Android only
  //             Card(
  //               elevation: 2,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(16),
  //               ),
  //               color: Theme.of(context).colorScheme.onSurface,
  //               child: Padding(
  //                 padding: const EdgeInsets.all(16.0),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       'HOW IT WORKS',
  //                       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
  //                     ),
  //                     const SizedBox(height: 12),
  //                     ListTile(
  //                       leading: Icon(Icons.filter_list, color: AppColors.lightPrimary),
  //                       title: Text('Smart Filter', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
  //                       subtitle: Text('Prioritizes contacts based on your interaction frequency', 
  //                         style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
  //                     ),
  //                     ListTile(
  //                       leading: Icon(Icons.group, color: AppColors.lightPrimary),
  //                       title: Text('Customizable Quantity', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
  //                       subtitle: Text('Choose how many contacts to import based on your needs', 
  //                         style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
  //                     ),
  //                     ListTile(
  //                       leading: Icon(Icons.security, color: AppColors.lightPrimary),
  //                       title: Text('Privacy First', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
  //                       subtitle: Text('Your contacts are only stored on your device and our secure servers', 
  //                         style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   ),
  //    if (feedbackProvider.isFabMenuOpen)
  //                 GestureDetector(
  //                   onTap: () {
  //                     // Optional: Close the menu when tapping the overlay
  //                     // You'll need to access the FeedbackFloatingButton's state
  //                     // This is handled automatically if the button listens to provider changes
  //                   },
  //                   child: Container(
  //                     color: Colors.black.withOpacity(0.55),
  //                     width: MediaQuery.of(context).size.width,
  //                     height: MediaQuery.of(context).size.height,
  //                   ),
  //                 ),
  //   ]
  //   ));
  // }

}

/// Full-screen contact picker widget for selecting contacts to import
  class _FullScreenContactPicker extends StatefulWidget {
    final List<fContacts.Contact> contacts;
    final List<Contact> existingContacts;
    final SocialGroup? selectedGroup;

    const _FullScreenContactPicker({
      required this.contacts,
      required this.existingContacts,
      this.selectedGroup,
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
    
    // Helper method to check if a contact already exists

  bool _isContactAlreadyExists(fContacts.Contact contact) {
    if (widget.existingContacts.isEmpty) return false;
    
    // Get all possible identifiers from the device contact
    final devicePhoneNumbers = contact.phones
        .map((phone) => _normalizePhoneNumber(phone.number)) // Use raw number first
        .where((phone) => phone.isNotEmpty)
        .toSet();
    
    // Also try normalized numbers
    final deviceNormalizedPhones = contact.phones
        .map((phone) => _normalizePhoneNumber(phone.normalizedNumber))
        .where((phone) => phone.isNotEmpty)
        .toSet();
    
    // Combine all phone variations
    final allDevicePhones = {...devicePhoneNumbers, ...deviceNormalizedPhones};
    
    // Get all emails from device contact
    final deviceEmails = contact.emails
        .map((email) => email.address.toLowerCase().trim())
        .where((email) => email.isNotEmpty)
        .toSet();
    
    // Get device contact name variations
    final deviceName = contact.displayName.toLowerCase().trim();
    final deviceFirstName = contact.name.first.toLowerCase().trim();
    final deviceLastName = contact.name.last.toLowerCase().trim();
    
    // Generate name variations for matching
    final deviceNameVariations = <String>{};
    if (deviceName.isNotEmpty) deviceNameVariations.add(deviceName);
    if (deviceFirstName.isNotEmpty && deviceLastName.isNotEmpty) {
      deviceNameVariations.add('$deviceFirstName $deviceLastName'.trim());
      deviceNameVariations.add('$deviceLastName, $deviceFirstName'.trim());
    }
    if (deviceFirstName.isNotEmpty) deviceNameVariations.add(deviceFirstName);
    if (deviceLastName.isNotEmpty) deviceNameVariations.add(deviceLastName);
    
    // Debug print
    //print('Checking contact: ${contact.displayName}');
    //print('Device phones: $allDevicePhones');
    //print('Device emails: $deviceEmails');
    //print('Device name variations: $deviceNameVariations');
    
    for (final existingContact in widget.existingContacts) {
      // Check 1: Phone number match (primary identifier)
      if (existingContact.phoneNumber.isNotEmpty) {
        final existingPhone = _normalizePhoneNumber(existingContact.phoneNumber);
        
        // Direct match
        if (allDevicePhones.contains(existingPhone)) {
          //print('MATCH: Phone number match for ${contact.displayName}');
          return true;
        }
        
        // Partial match for numbers (last 10 digits)
        if (existingPhone.length >= 10) {
          final existingLast10 = existingPhone.substring(existingPhone.length - 10);
          for (final devicePhone in allDevicePhones) {
            if (devicePhone.length >= 10) {
              final deviceLast10 = devicePhone.substring(devicePhone.length - 10);
              if (existingLast10 == deviceLast10) {
                //print('MATCH: Last 10 digits match for ${contact.displayName}');
                return true;
              }
            }
          }
        }
      }
      
      // Check 2: Email match (secondary identifier)
      if (existingContact.email.isNotEmpty && deviceEmails.isNotEmpty) {
        final existingEmail = existingContact.email.toLowerCase().trim();
        if (deviceEmails.contains(existingEmail)) {
          //print('MATCH: Email match for ${contact.displayName}');
          return true;
        }
      }
      
      // Check 3: Name-based matching (tertiary identifier)
      // Only use name matching if we have a name and it's reasonably unique
      if (existingContact.name.isNotEmpty && deviceNameVariations.isNotEmpty) {
        final existingName = existingContact.name.toLowerCase().trim();
        
        // Direct name match
        if (deviceNameVariations.contains(existingName)) {
          //print('MATCH: Direct name match for ${contact.displayName}');
          return true;
        }
        
        // Check if names are very similar (for typos or slight variations)
        // This is useful when the same contact might be stored with slight name variations
        for (final deviceNameVar in deviceNameVariations) {
          // If names are long enough and one contains the other
          if (deviceNameVar.length > 3 && existingName.length > 3) {
            if (deviceNameVar.contains(existingName) || existingName.contains(deviceNameVar)) {
              // Calculate similarity (simple check - can be enhanced)
              final commonChars = deviceNameVar.split('').where((c) => existingName.contains(c)).length;
              final similarity = commonChars / existingName.length;
              
              if (similarity > 0.8) { // 80% similarity threshold
                //print('MATCH: High similarity name match for ${contact.displayName}');
                return true;
              }
            }
          }
        }
      }
      
      // Check 4: Combined evidence (if we have multiple partial matches)
      int evidenceScore = 0;
      
      // Phone partial match evidence
      if (existingContact.phoneNumber.isNotEmpty) {
        final existingPhone = _normalizePhoneNumber(existingContact.phoneNumber);
        if (existingPhone.length >= 7) {
          final existingLast7 = existingPhone.substring(existingPhone.length - 7);
          for (final devicePhone in allDevicePhones) {
            if (devicePhone.length >= 7) {
              final deviceLast7 = devicePhone.substring(devicePhone.length - 7);
              if (existingLast7 == deviceLast7) {
                evidenceScore += 3;
                break;
              }
            }
          }
        }
      }
      
      // Email domain match evidence
      if (existingContact.email.isNotEmpty && deviceEmails.isNotEmpty) {
        final existingDomain = existingContact.email.split('@').last;
        for (final deviceEmail in deviceEmails) {
          if (deviceEmail.contains('@')) {
            final deviceDomain = deviceEmail.split('@').last;
            if (existingDomain == deviceDomain) {
              evidenceScore += 2;
              break;
            }
          }
        }
      }
      
      // Name partial match evidence
      if (existingContact.name.isNotEmpty && deviceNameVariations.isNotEmpty) {
        final existingNameWords = existingContact.name.toLowerCase().split(' ');
        for (final deviceNameVar in deviceNameVariations) {
          final deviceNameWords = deviceNameVar.split(' ');
          
          // Check if they share at least one word
          for (final existingWord in existingNameWords) {
            if (existingWord.length > 2) { // Ignore short words
              for (final deviceWord in deviceNameWords) {
                if (deviceWord.length > 2 && deviceWord.contains(existingWord) || existingWord.contains(deviceWord)) {
                  evidenceScore += 1;
                  break;
                }
              }
            }
          }
        }
      }
      
      // If we have strong combined evidence, consider it a match
      if (evidenceScore >= 4) {
        //print('MATCH: Combined evidence (score $evidenceScore) for ${contact.displayName}');
        return true;
      }
    }
    
    //print('NO MATCH found for ${contact.displayName}');
    return false;
  }

  // Enhanced phone number normalization for iOS
  String _normalizePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return '';
    
    // First, extract all digits
    String digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Handle iOS-specific cases
    if (Platform.isIOS) {
      // If we have a valid number
      if (digits.isNotEmpty) {
        // US/Canada: If it's 11 digits starting with 1, also consider the 10-digit version
        if (digits.length == 11 && digits.startsWith('1')) {
          return digits; // Keep the full number
        }
        
        // If it's 10 digits, it's a standard US/Canada number
        if (digits.length == 10) {
          return digits;
        }
        
        // For international numbers, keep as is
        return digits;
      }
      
      // If no digits found but we have a plus sign, try to extract differently
      if (phoneNumber.contains('+')) {
        // Keep the plus and digits
        final plusDigits = phoneNumber.replaceAll(RegExp(r'[^0-9\+]'), '');
        if (plusDigits.isNotEmpty) {
          return plusDigits.replaceAll('+', ''); // Remove plus for storage
        }
      }
    }
    
    return digits;
  }

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
      final cacheKey = contact.id;
      
      if (_avatarIndexCache.containsKey(cacheKey)) {
        return _avatarIndexCache[cacheKey]!;
      }
      
      final seed = cacheKey.isEmpty ? 'default' : cacheKey;
      var hash = 0;
      for (var i = 0; i < seed.length; i++) {
        hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
      }
      final index = (hash.abs() % 6) + 1;
      
      _avatarIndexCache[cacheKey] = index;
      return index;
    }

    void _selectAllFiltered() {
      setState(() {
        for (final c in _filteredContacts) {
          if (!_tempSelected.contains(c) && !_isContactAlreadyExists(c)) {
            _tempSelected.add(c);
          }
        }
      });
    }

    String _getContactInitials(String name) {
      if (name.isEmpty) return '?';
      
      final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
      
      if (parts.length >= 2) {
        return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
      } else if (parts.length == 1) {
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
      final isDark = themeProvider.isDarkMode;
      // final scheme = Theme.of(context).colorScheme;

      final scaffoldBg = isDark ? AppColors.darkBackground : const Color(0xFFF2EEE8);
      final cardBg     = isDark ? AppColors.darkSurfaceContainerHigh : Colors.white;
      final fieldBg    = isDark ? AppColors.darkSurfaceContainerHighest : const Color(0xFFECE7E2);
      final textP      = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
      final textS      = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

      // Alphabetical sections
      final Map<String, List<fContacts.Contact>> alphaSections = {};
      for (final c in _filteredContacts) {
        final letter = c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '#';
        alphaSections.putIfAbsent(letter, () => []).add(c);
      }
      final sortedLetters = alphaSections.keys.toList()..sort();

      // "Frequently contacted" = already-in-nudge contacts at top
      final frequent = _filteredContacts
          .where((c) => _isContactAlreadyExists(c))
          .take(3)
          .toList();

      return GestureDetector(
        onTap: _dismissKeyboard,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: scaffoldBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: textP, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text('SELECT CONTACTS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: textP, letterSpacing: 0.5)),
            actions: [
              IconButton(
                icon: Icon(Icons.select_all_rounded,
                    color: AppColors.lightPrimary, size: 22),
                tooltip: 'Select all',
                onPressed: _selectAllFiltered,
              ),
              IconButton(
                icon: Icon(Icons.deselect_rounded, color: textS, size: 22),
                tooltip: 'Clear selection',
                onPressed: _clearFilteredSelection,
              ),
            ],
          ),

          body: Column(children: [
            // Group banner
            if (widget.selectedGroup != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.lightPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.lightPrimary.withOpacity(0.2))),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: () {
                        try {
                          return Color(int.parse(widget.selectedGroup!.colorCode
                              .replaceAll('#', '0xFF')));
                        } catch (_) { return AppColors.lightPrimary; }
                      }(),
                      shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Adding to: ${widget.selectedGroup!.name}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color:  isDark?Colors.white: AppColors.lightPrimary))),
                ]),
              ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(9999)),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.beVietnamPro(fontSize: 14, color: textP),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: textS, size: 20),
                    hintText: 'Search by name or number...',
                    hintStyle: GoogleFonts.beVietnamPro(fontSize: 14, color: textS),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: _applyFilter,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Contact list
            Expanded(
              child: _filteredContacts.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 56, color: textS.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('No contacts found',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16, fontWeight: FontWeight.w600,
                            color: textP)),
                        if (_searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Try a different search term',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13, color: textS))),
                      ]))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      children: [
                        // Frequently contacted (already-in-nudge) section
                        if (frequent.isNotEmpty && _searchController.text.isEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                            child: Text('FREQUENTLY CONTACTED',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: textS, letterSpacing: 0.8))),
                          ...frequent.map((c) =>
                              _buildContactCard(c, cardBg, textP, textS, isDark)),
                          const SizedBox(height: 12),
                        ],
                        // Alphabetical sections
                        ...sortedLetters.expand((letter) => [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                            child: Text(letter,
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: textS, letterSpacing: 0.5))),
                          ...alphaSections[letter]!.map((c) =>
                              _buildContactCard(c, cardBg, textP, textS, isDark)),
                        ]),
                      ],
                    ),
            ),
          ]),

          // Bottom bar
          bottomNavigationBar: Container(
            color: scaffoldBg,
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(context).padding.bottom + 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('Cancel',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 16, fontWeight: FontWeight.w500, color: textS)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _tempSelected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _tempSelected),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _tempSelected.isEmpty ? 0.45 : 1.0,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF751FE7), Color(0xFF9C4DFF)]),
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: _tempSelected.isNotEmpty
                          ? [BoxShadow(
                              color: AppColors.lightPrimary.withOpacity(0.4),
                              blurRadius: 16, offset: const Offset(0, 5))]
                          : null,
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text('Import (${_tempSelected.length})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    // ── Contact card ──────────────────────────────────────────────────────
    Widget _buildContactCard(
      fContacts.Contact contact,
      Color cardBg, Color textP, Color textS, bool isDark,
    ) {
      final isSelected    = _tempSelected.contains(contact);
      final alreadyExists = _isContactAlreadyExists(contact);
      final primaryPhone  = contact.phones.isNotEmpty
          ? contact.phones.first.number : '';
      final avatarIndex   = _getAvatarIndex(contact);
      final initials      = contact.displayName.isNotEmpty
          ? _getContactInitials(contact.displayName) : '?';

      return GestureDetector(
        onTap: alreadyExists ? null : () => setState(() {
          if (isSelected) {
            _tempSelected.remove(contact);
          } else {
            _tempSelected.add(contact);
          }
        }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.14 : 0.05),
              blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            // Avatar
            Stack(clipBehavior: Clip.none, children: [
              Opacity(
                opacity: alreadyExists ? 0.65 : 1.0,
                child: contact.photo != null && contact.photo!.isNotEmpty
                    ? ClipOval(child: Image.memory(
                        contact.photo!, width: 48, height: 48,
                        fit: BoxFit.cover))
                    : ClipOval(
                        child: SizedBox(width: 48, height: 48,
                          child: Stack(fit: StackFit.expand, children: [
                            Image.asset('assets/contact-icons/$avatarIndex.png',
                                fit: BoxFit.cover),
                            Container(color: Colors.black.withOpacity(
                                isDark ? 0.38 : 0.18)),
                            Center(child: Text(initials,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: [Shadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 4)]))),
                          ]))),
              ),
              if (alreadyExists)
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.lightPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBg, width: 1.5)),
                    child: const Icon(Icons.check, color: Colors.white, size: 10))),
            ]),
            const SizedBox(width: 14),

            // Name + phone
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(contact.displayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: alreadyExists ? textS : textP),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (alreadyExists) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color:  isDark?AppColors.lightPrimary.withOpacity(0.4):AppColors.lightPrimary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text('ALREADY IN NUDGE',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: isDark?Colors.white:AppColors.lightPrimary,
                          letterSpacing: 0.3))),
                  ],
                ]),
                if (primaryPhone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(primaryPhone,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, color: textS)),
                ],
              ],
            )),
            const SizedBox(width: 12),

            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.lightPrimary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.lightPrimary
                      : alreadyExists
                          ?  isDark?Colors.white: AppColors.lightPrimary.withOpacity(0.4)
                          : textS.withOpacity(0.35),
                  width: 1.5)),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : alreadyExists
                      ? Icon(Icons.check_rounded,
                          color:  isDark?Colors.white: AppColors.lightPrimary.withOpacity(0.6), size: 14)
                      : null,
            ),
          ]),
        ),
      );
    }
}