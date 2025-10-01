// lib/screens/contacts/import_contacts_screen.dart
import 'package:flutter/material.dart';
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
  int _selectedQuantity = 50; // 0 means all contacts
  bool _useSmartFilter = true;
  List<int> _quantityOptions = [25, 50, 100, 150]; // 0 represents "All Contacts"

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
    
    if (result['success'] == true) {
      if (result['importedCount'] == 0) {
        setState(() {
          _statusMessage = 'No new contacts to import - all contacts already exist in Nudge';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All contacts already imported')),
        );
      } else {
        setState(() {
          _statusMessage = 'Successfully imported ${result['importedCount']} contacts!';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contacts imported successfully')),
        );
      }
      
      // Navigate after a short delay to show success message
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


  String _getQuantityLabel(int quantity) {
    return quantity == 0 ? 'All Contacts' : 'First $quantity Contacts';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NUDGE', style: AppTextStyles.title3.copyWith(color: Colors.black, fontFamily: 'RobotoMono'),),
                  centerTitle: true,
                  iconTheme: IconThemeData(color: Colors.black),
                  backgroundColor: Colors.white
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          // crossAxisAlignment: CrossAxisAlignment.start,
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
                          checkmarkColor: const Color.fromRGBO(45, 161, 175, 1),
                          labelStyle: TextStyle(
                            color: _selectedQuantity == quantity 
                                ? const Color.fromRGBO(45, 161, 175, 1)
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
                    Row(
                      children: [
                        Switch(
                          value: _useSmartFilter,
                          onChanged: (value) {
                            setState(() {
                              _useSmartFilter = value;
                            });
                          },
                          activeColor: const Color.fromRGBO(45, 161, 175, 1),
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
                    
                    // Import Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isImporting ? null : _importDeviceContacts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(Color.fromRGBO(45, 161, 175, 1)),
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
                            '${_processedCount}/${_totalCount}',
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
                color: _statusMessage.contains('Success') 
                    ? Colors.green[50] 
                    : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.contains('Success') 
                            ? Icons.check_circle 
                            : Icons.error,
                        color: _statusMessage.contains('Success') 
                            ? Colors.green 
                            : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusMessage.contains('Success') 
                                  ? 'Import Successful' 
                                  : 'Import Failed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _statusMessage.contains('Success') 
                                    ? Colors.green 
                                    : Colors.red,
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
              child: Padding(
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
                      leading: Icon(Icons.filter_list, color: Color.fromRGBO(45, 161, 175, 1)),
                      title: Text('Smart Filter', style: TextStyle(fontWeight: FontWeight.w800),),
                      subtitle: Text('Prioritizes contacts based on your interaction frequency'),
                    ),
                    ListTile(
                      leading: Icon(Icons.group, color: Color.fromRGBO(45, 161, 175, 1)),
                      title: Text('Customizable Quantity', style: TextStyle(fontWeight: FontWeight.w800),),
                      subtitle: Text('Choose how many contacts to import based on your needs'),
                    ),
                    ListTile(
                      leading: Icon(Icons.security, color: Color.fromRGBO(45, 161, 175, 1)),
                      title: Text('Privacy First', style: TextStyle(fontWeight: FontWeight.w800),),
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