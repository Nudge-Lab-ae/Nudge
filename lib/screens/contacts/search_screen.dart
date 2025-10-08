import 'package:flutter/material.dart';
import 'package:nudge/screens/contacts/contacts_list_screen.dart';
// import 'add_contact_screen.dart';
// import '../notifications/notifications_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NUDGE'),
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => const NotificationsScreen(),
              //   ),
              // );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Organize by:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Chip(
                  label: const Text('Connection Type'),
                  backgroundColor: const Color.fromRGBO(37, 150, 190, 0.2),
                ),
                const SizedBox(width: 10),
                const Chip(label: Text('Frequency')),
                const SizedBox(width: 10),
                const Chip(label: Text('Social Group')),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Jane Adams',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            const Text('Diana Lee'),
            const SizedBox(height: 15),
            const Text('Hannah Johnson'),
            const SizedBox(height: 15),
            const Text('Alex White'),
            const SizedBox(height: 30),
            const Text(
              'Sarah Smith',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  'Add Contact',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
       // In the floatingActionButton onPressed handler:
onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>  ContactsListScreen(showAppBar: true, hideButton: (){},), // Changed from AddContactScreen
    ),
  );
},
        backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}