// lib/screens/contacts/import_contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/screens/contacts/imported_contacts_screen.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
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

  Future<void> _importDeviceContacts() async {
    setState(() {
      _isImporting = true;
      _processedCount = 0;
      _totalCount = 0;
      _statusMessage = 'Preparing to import...';
    });
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;
    
    final syncService = ContactSyncService(apiService: apiService);
    
    try {
      final result = await syncService.importDeviceContacts(
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
          _statusMessage = 'Successfully imported ${result['importedCount']} contacts!';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contacts imported successfully')),
        );
        
        // Navigate after a short delay to show success message
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ImportedContactsScreen(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import Contacts', style: AppTextStyles.title3.copyWith(color: Colors.white),),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import Your Contacts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Easily import your existing contacts to get started with Nudge',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.contacts, size: 50, color: Color.fromRGBO(37, 150, 190, 1)),
                    const SizedBox(height: 16),
                    const Text(
                      'Device Contacts',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    if (_isImporting) ...[
                      const SizedBox(height: 16),
                      CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      if (_totalCount > 0) ...[
                        LinearProgressIndicator(
                          value: _processedCount / _totalCount,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_processedCount / $_totalCount',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ] else ...[
                      const Text(
                        'Import contacts from your device',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _importDeviceContacts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
                        ),
                        child: const Text('Import Now', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (!_isImporting && _statusMessage.isNotEmpty) ...[
              Card(
                color: _statusMessage.contains('Success') ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.contains('Success') ? Icons.check_circle : Icons.error,
                        color: _statusMessage.contains('Success') ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _statusMessage.contains('Success') ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Other import options (Gmail, etc.)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.mail, size: 50, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Gmail Contacts',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Import contacts from your Gmail account (Coming Soon)',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gmail integration coming soon')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      child: const Text('Coming Soon', style: TextStyle(color: Colors.white)),
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