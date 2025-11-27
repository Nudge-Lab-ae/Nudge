// lib/screens/contacts/import_contacts_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
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
    if (user == null) return;

    final syncService = ContactSyncService(apiService: apiService);

    try {
      final result = await syncService.importDeviceContacts(
        limit: _selectedQuantity,
        useSmartFilter: _useSmartFilter,
        onProgress: (processed, total) {
          setState(() {
            _processedCount = processed;
            _totalCount = total;
            _statusMessage = 'Processing $processed of $total contacts...';
          });
        },
      );

      setState(() => _isImporting = false);

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
        } else {
          setState(() {
            _statusMessage =
                'Successfully imported ${result['importedCount']} contacts!';
          });

          // _scheduleNudgesForImportedContacts(result['importedCount']);
          _showImportSuccessAndScheduleNudges(result['importedCount'], user.uid);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts imported successfully')),
          );
        }

        await Future.delayed(const Duration(seconds: 2));
      } else {
        setState(() {
          _statusMessage = 'Import failed: ${result['message']}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import contacts: ${result['message']}')),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _statusMessage = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import contacts: $e')),
      );
    }
  }

  void _showImportSuccessAndScheduleNudges(int importedCount, String userId) async {
  // Show initial success message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text('Imported $importedCount contacts successfully!'),
        ],
      ),
      backgroundColor: Colors.green,
    ),
  );

  // Schedule nudges in background
  await _scheduleNudgesForImportedContacts(importedCount, userId);
}

  /// Multi-select picker UI embedded in the screen.
  /// This fetches contacts, shows a checkbox list, and imports the selected ones.
  Future<void> _pickContactsAndImport() async {
    final permissionOk = await fContacts.FlutterContacts.requestPermission();
    if (!permissionOk) {
      _showSettingsDialog('Contacts permission is required to pick contacts');
      return;
    }

    final contacts = await fContacts.FlutterContacts.getContacts(withProperties: true);

    final selectedContacts = await showDialog<List<fContacts.Contact>>(
      context: context,
      builder: (context) {
        final tempSelected = <fContacts.Contact>[];
        final searchController = TextEditingController();
        List<fContacts.Contact> filtered = List.of(contacts);

        void applyFilter(String query) {
          final q = query.trim().toLowerCase();
          filtered = q.isEmpty
              ? List.of(contacts)
              : contacts.where((c) {
                  final name = c.displayName.toLowerCase();
                  final phones = c.phones.map((p) => p.number.toLowerCase()).join(' ');
                  final emails = c.emails.map((e) => e.address.toLowerCase()).join(' ');
                  return name.contains(q) || phones.contains(q) || emails.contains(q);
                }).toList();
        }

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Contacts'),
              content: SizedBox(
                width: double.maxFinite,
                height: 520,
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search by name, phone, or email',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          applyFilter(val);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Info + select all
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Showing ${filtered.length} of ${contacts.length}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setStateDialog(() {
                              // Select all filtered
                              for (final c in filtered) {
                                if (!tempSelected.contains(c)) {
                                  tempSelected.add(c);
                                }
                              }
                            });
                          },
                          icon: const Icon(Icons.select_all),
                          label: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () {
                            setStateDialog(() {
                              // Clear only filtered from selection
                              tempSelected.removeWhere((c) => filtered.contains(c));
                            });
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // List of contacts
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No contacts found'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final contact = filtered[index];
                                final isSelected = tempSelected.contains(contact);
                                final primaryPhone = contact.phones.isNotEmpty
                                    ? contact.phones.first.number
                                    : '';
                                final primaryEmail = contact.emails.isNotEmpty
                                    ? contact.emails.first.address
                                    : '';
                                return CheckboxListTile(
                                  title: Text(contact.displayName),
                                  subtitle: Text(
                                    [primaryPhone, primaryEmail]
                                        .where((s) => s.isNotEmpty)
                                        .join(' • '),
                                  ),
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setStateDialog(() {
                                      if (checked == true) {
                                        tempSelected.add(contact);
                                      } else {
                                        tempSelected.remove(contact);
                                      }
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                    ),
                    // Selection count
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Selected: ${tempSelected.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  icon: const Icon(Icons.download),
                  label: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedContacts == null || selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts selected')),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    final syncService = ContactSyncService(apiService: apiService);

    setState(() {
      _isImporting = true;
      _processedCount = 0;
      _totalCount = selectedContacts.length;
      _statusMessage = 'Importing selected contacts...';
    });

    // Note: ContactSyncService.importFromContactPicker should be refactored to accept pickedContacts
    final result = await syncService.importFromContactPicker(
      pickedContacts: selectedContacts,
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
            'Successfully imported ${result['importedCount']} contacts from picker!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts imported successfully')),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GradientText( text: 'NUDGE', style: TextStyle(fontSize: 25, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF5CDEE5), // #5CDEE5
                  Color(0xFF2D85F6), // #2D85F6
                  Color(0xFF7A4BFF), // #7A4BFF
                ], stops: [0.0, 0.6, 1.0], begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        // Text(
        //   'NUDGE',
        //   style: AppTextStyles.title2.copyWith(
        //     color: const Color(0xff3CB3E9),
        //     fontFamily: 'RobotoMono',
        //   ),
        // ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xff3CB3E9)),
        backgroundColor: Colors.white,
      ),
      floatingActionButton: FeedbackFloatingButton(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              'Import Your Contacts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Easily import your existing contacts to get started with Nudge',
              style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 30),

            // Import Options Card
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
                      'Import Options',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Quantity Selection
                    const Text(
                      'How many contacts would you like to import?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                                : Colors.black,
                            fontWeight: _selectedQuantity == quantity
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Smart Filter Option
                    Platform.isIOS
                    ? Center()
                    : Row(
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
                                'Smart Filter',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                            // iconAlignment: IconAlignment.end,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Color(0xff3CB3E9)),
                            ),
                            icon: Padding(
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
                color: _statusMessage.contains('Success') ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.contains('Success') ? Icons.check_circle : Icons.error,
                        color: _statusMessage.contains('Success') ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusMessage.contains('Success') ? 'Import Successful' : 'Import Failed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _statusMessage.contains('Success') ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _statusMessage,
                              style: TextStyle(
                                color: _statusMessage.contains('Success')
                                    ? Colors.green[800]
                                    : Colors.red[800],
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

            // Information Section
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
                      'How It Works',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    ListTile(
                      leading: Icon(Icons.filter_list, color: Color(0xff3CB3E9)),
                      title: Text('Smart Filter', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Prioritizes contacts based on your interaction frequency'),
                    ),
                    ListTile(
                      leading: Icon(Icons.group, color: Color(0xff3CB3E9)),
                      title: Text('Customizable Quantity', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Choose how many contacts to import based on your needs'),
                    ),
                    ListTile(
                      leading: Icon(Icons.security, color: Color(0xff3CB3E9)),
                      title: Text('Privacy First', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Your contacts are only stored on your device and our secure servers'),
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
