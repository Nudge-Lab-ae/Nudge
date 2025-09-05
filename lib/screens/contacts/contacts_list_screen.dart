// lib/screens/contacts/contacts_list_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
import '../notifications/notifications_screen.dart';
import 'contact_detail_screen.dart';
import 'add_contact_screen.dart';
import '../../models/contact.dart';
// import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class ContactsListScreen extends StatefulWidget {
  final String? filter;
  
  const ContactsListScreen({super.key, this.filter});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final apiService = Provider.of<ApiService>(context);
    
    // If user is not logged in, show empty state
    if (user == null) {
      return _buildEmptyState();
    }
    
    // Create database service for the current user
    // final databaseService = DatabaseService(uid: user.uid);
    
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_getTitle(widget.filter), style: AppTextStyles.button.copyWith(color: Colors.white),),
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamProvider<List<Contact>>(
        create: (context) => apiService.getContactsStream(),
        initialData: const [],
        child: Consumer<List<Contact>>(
          builder: (context, contacts, child) {
            // Apply filter if provided
            final filteredContacts = _applyFilter(contacts, widget.filter);
            
            // Show empty state if no contacts
            if (filteredContacts.isEmpty) {
              return _buildEmptyState(filter: widget.filter);
            }
            
            // Filter contacts based on search query
            final searchedContacts = filteredContacts.where((contact) {
              return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  contact.connectionType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  contact.socialGroups.any((group) => group.toLowerCase().contains(_searchQuery.toLowerCase()));
            }).toList();
            
            // Show empty state if no contacts match search
            if (searchedContacts.isEmpty) {
              return Column(
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'No contacts found for "$_searchQuery"',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              );
            }
            
            return Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: ListView.builder(
                    itemCount: searchedContacts.length,
                    itemBuilder: (context, index) {
                      final contact = searchedContacts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: contact.imageUrl.isNotEmpty
                              ? NetworkImage(contact.imageUrl)
                              : null,
                          child: contact.imageUrl.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(contact.name),
                        subtitle: Text(contact.connectionType),
                        trailing: Text(
                          'Last: ${contact.lastContacted.difference(DateTime.now()).inDays.abs()}d ago',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContactDetailScreen(contact: contact),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContactScreen(),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search contacts...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState({String? filter}) {
    String title;
    String description;
    
    switch (filter) {
      case 'vip':
        title = 'No VIP contacts yet';
        description = 'Mark contacts as VIP to see them here';
        break;
      case 'needs_attention':
        title = 'No contacts need attention';
        description = 'All your contacts have been contacted recently';
        break;
      default:
        title = 'No contacts yet';
        description = 'Add your first contact to get started';
    }
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contacts,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ), textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddContactScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
              ),
              child: Text('Add Contact', style: AppTextStyles.button.copyWith(color: Colors.white),),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContactScreen(),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _getTitle(String? filter) {
    switch (filter) {
      case 'vip':
        return 'VIP Contacts';
      case 'needs_attention':
        return 'Contacts Needing Attention';
      default:
        return 'All Contacts';
    }
  }

  List<Contact> _applyFilter(List<Contact> contacts, String? filter) {
    switch (filter) {
      case 'vip':
        return contacts.where((c) => c.isVIP).toList();
      case 'needs_attention':
        return contacts.where((c) => 
          c.lastContacted.isBefore(DateTime.now().subtract(const Duration(days: 30)))
        ).toList();
      default:
        return contacts;
    }
  }
}