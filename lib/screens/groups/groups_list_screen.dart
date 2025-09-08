import 'package:flutter/material.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
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
  Stream<List<SocialGroup>>? _groupsStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    _groupsStream = apiService.getGroupsStream().handleError((error) {
      print('Error in groups stream: $error');
      return <SocialGroup>[];
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reinitialize streams when dependencies change
    _initializeStreams();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final apiService = Provider.of<ApiService>(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view groups')),
      );
    }

    return StreamProvider<List<Contact>>.value(
      value: apiService.getContactsStream().handleError((error) {
        print('Error in contacts stream: $error');
        return <Contact>[];
      }),
      initialData: const [],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Social Groups', style: TextStyle(color: Colors.white),),
          leading: IconButton(
            icon: const Icon(
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
        body: StreamBuilder<List<SocialGroup>>(
          stream: _groupsStream,
          builder: (context, groupsSnapshot) {
            if (groupsSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading groups',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      groupsSnapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initializeStreams();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
                      ),
                      child: const Text('Retry', style: TextStyle(color: Colors.white),),
                    ),
                  ],
                ),
              );
            }

            if (!groupsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final groups = groupsSnapshot.data!;
            
            return Consumer<List<Contact>>(
              builder: (context, contacts, child) {
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
            );
          },
        ),
      ),
    );
  }

  // Rest of the methods remain the same as in the previous implementation
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
              '${group.memberCount} members • ${group.frequency} times per ${group.period.toLowerCase()}',
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
    int frequency = 4;

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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              TextFormField(
                initialValue: frequency.toString(),
                decoration: const InputDecoration(
                  labelText: 'Frequency (times per period)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  frequency = int.tryParse(value) ?? 4;
                },
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
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    description: descriptionController.text,
                    period: period,
                    frequency: frequency,
                    memberIds: [],
                    memberCount: 0,
                    lastInteraction: DateTime.now(),
                    colorCode: '#2596BE',
                  );
                  
                  try {
                    await apiService.addGroup(newGroup);
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating group: $e'),
                      ),
                    );
                  }
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
    int frequency = group.frequency;

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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              TextFormField(
                initialValue: frequency.toString(),
                decoration: const InputDecoration(
                  labelText: 'Frequency (times per period)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  frequency = int.tryParse(value) ?? group.frequency;
                },
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
                    frequency: frequency,
                  );
                  
                  try {
                    await apiService.updateGroup(updatedGroup);
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating group: $e'),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
              ),
              child:  Text('Save', style: AppTextStyles.button.copyWith(color: Colors.white),),
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
                Text(
                  'Contact: ${group.frequency} times per ${group.period.toLowerCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
                      backgroundImage: contact.imageUrl.isNotEmpty
                          ? NetworkImage(contact.imageUrl)
                          : null,
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
                        
                        try {
                          await apiService.updateGroup(updatedGroup);
                          Navigator.of(context).pop();
                          _showGroupDetails(context, updatedGroup, 
                              members.where((m) => m.id != contact.id).toList(), 
                              apiService);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error removing member: $e'),
                            ),
                          );
                        }
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