// lib/screens/contacts/imported_contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/subscription.dart';
import 'package:nudge/providers/subscription_provider.dart';
import 'package:nudge/screens/subscription/paywall_screen.dart';
import 'package:nudge/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
// import '../../services/auth_service.dart';
// import '../../models/contact.dart';
import 'edit_contact_screen.dart';

class ImportedContactsScreen extends StatefulWidget {
  const ImportedContactsScreen({super.key});

  @override
  State<ImportedContactsScreen> createState() => _ImportedContactsScreenState();
}

class _ImportedContactsScreenState extends State<ImportedContactsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _importedContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImportedContacts();
  }

  Future<void> _loadImportedContacts() async {
    try {
      final contacts = await _apiService.getImportedContacts();
      setState(() {
        _importedContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      //print('Error loading imported contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _convertToRegularContact(Map<String, dynamic> contact) async {
    final sub = Provider.of<SubscriptionProvider>(context, listen: false);
    final existing = await _apiService.getAllContacts();
    if (!sub.canAddContact(existing.length)) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PaywallScreen(
          highlightTier: sub.tier == SubscriptionTier.free
              ? SubscriptionTier.plus
              : SubscriptionTier.pro,
        ),
      ));
      return;
    }
    try {
      await _apiService.convertImportedToRegularContact(contact);
      await _loadImportedContacts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact added to your universe')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to convert contact: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Imported Contacts'),
        backgroundColor: AppColors.lightPrimary,
      ),
      body: _importedContacts.isEmpty
          ? const Center(
              child: Text('No imported contacts'),
            )
          : ListView.builder(
              itemCount: _importedContacts.length,
              itemBuilder: (context, index) {
                final contact = _importedContacts[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(contact['name'] ?? 'Unknown'),
                  subtitle: Text(contact['phoneNumber'] ?? contact['email'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _convertToRegularContact(contact),
                    tooltip: 'Add to regular contacts',
                  ),
                  onTap: () {
                    // Navigate to a screen to edit and convert the contact
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditContactScreen(
                          contactId: '', // Empty for new contacts
                          isImported: true,
                          importedContact: contact,
                        ),
                      ),
                    ).then((_) => _loadImportedContacts());
                  },
                );
              },
            ),
    );
  }
}