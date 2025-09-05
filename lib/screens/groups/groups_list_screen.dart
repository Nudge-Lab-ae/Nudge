import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:provider/provider.dart';
// import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/social_group.dart';
import '../../models/contact.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view groups')),
      );
    }

    final apiService = ApiService();

    return MultiProvider(
      providers: [
        StreamProvider<List<SocialGroup>>.value(
          value: apiService.getGroupsStream(),
          initialData: const [],
        ),
        StreamProvider<List<Contact>>.value(
          value: apiService.getContactsStream(),
          initialData: const [],
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Social Groups', style: TextStyle(color: Colors.white),),
            leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context); 
                },
              ),
          backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                _showCreateGroupDialog(context, apiService);
              },
            ),
          ],
        ),
        body: Consumer2<List<SocialGroup>, List<Contact>>(
          builder: (context, groups, contacts, child) {
            // Filter groups based on search query
            final filteredGroups = groups.where((group) {
              return group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  group.description.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            if (groups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.group,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No groups yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your first group to organize your contacts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _showCreateGroupDialog(context, apiService);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
                      ),
                      child: const Text('Create Group', style: TextStyle(color: Colors.white),),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search groups...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      return _buildGroupCard(context, group, contacts, apiService);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, SocialGroup group, List<Contact> contacts, ApiService apiService) {
    // Get group members
    final groupMembers = contacts.where((contact) => group.memberIds.contains(contact.id)).toList();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(int.parse(group.colorCode.substring(1, 7), radix: 16) + 0xFF000000),
          child: Text(
            group.name[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(group.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.description),
            const SizedBox(height: 4),
            Text(
              '${group.memberCount} members • ${group.frequency}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            _showEditGroupDialog(context, group, apiService);
          },
        ),
        onTap: () {
          _showGroupDetails(context, group, groupMembers, apiService);
        },
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, ApiService apiService) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String period = 'Monthly';
    int frequency = 2;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: period,
                onChanged: (String? newValue) {
                  period = newValue!;
                },
                items: <String>['Weekly', 'Monthly', 'Quarterly', 'Annually']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: const InputDecoration(
                  labelText: 'Contact Period',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final newGroup = SocialGroup(
                    id: '',
                    name: nameController.text,
                    description: descriptionController.text,
                    period: period,
                    frequency: frequency,
                    memberIds: [],
                    memberCount: 0,
                    lastInteraction: DateTime.now(),
                    colorCode: '#2596BE',
                  );
                  
                  await apiService.addGroup(newGroup);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
              ),
              child: const Text('Create', style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }

  void _showEditGroupDialog(BuildContext context, SocialGroup group, ApiService apiService) {
    final nameController = TextEditingController(text: group.name);
    final descriptionController = TextEditingController(text: group.description);
    String period = group.period;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: period,
                onChanged: (String? newValue) {
                  period = newValue!;
                },
                items: <String>['Weekly', 'Monthly', 'Quarterly', 'Annually']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: const InputDecoration(
                  labelText: 'Contact Frequency',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final updatedGroup = group.copyWith(
                    name: nameController.text,
                    description: descriptionController.text,
                    period: period,
                  );
                  
                  await apiService.updateGroup(updatedGroup);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showGroupDetails(BuildContext context, SocialGroup group, List<Contact> members, ApiService apiService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(group.name),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(group.description),
                const SizedBox(height: 16),
                const Text(
                  'Group Members',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  const Text('No members in this group')
                else
                  ...members.map((contact) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(contact.imageUrl),
                      child: contact.imageUrl.isEmpty 
                          ? const Icon(Icons.person) 
                          : null,
                    ),
                    title: Text(contact.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () async {
                        // Remove member from group
                        final updatedMemberIds = List<String>.from(group.memberIds)..remove(contact.id);
                        final updatedGroup = group.copyWith(
                          memberIds: updatedMemberIds,
                          memberCount: updatedMemberIds.length,
                        );
                        
                        await apiService.updateGroup(updatedGroup);
                        Navigator.of(context).pop();
                        _showGroupDetails(context, updatedGroup, 
                            members.where((m) => m.id != contact.id).toList(), 
                            apiService);
                      },
                    ),
                  )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}