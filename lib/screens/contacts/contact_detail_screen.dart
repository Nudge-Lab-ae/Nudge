// lib/screens/contacts/contact_detail_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
import 'package:nudge/services/api_service.dart';
// import 'package:nudge/screens/notifications/notifications_screen.dart';
// import 'package:nudge/services/nudge_service.dart';
import 'package:nudge/theme/text_styles.dart';
import 'package:nudge/widgets/smart_tagging_suggestions.dart';
// import 'package:nudge/theme/text_styles.dart';
import 'package:provider/provider.dart';
// import '../notifications/notifications_screen.dart';
// import 'add_contact_screen.dart';
import '../../models/contact.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
// import '../../widgets/connection_type_chip.dart';
// import '../../widgets/social_group_chip.dart';
// import '../../widgets/contact_info_item.dart';

class ContactDetailScreen extends StatelessWidget {
  final Contact contact;
  
  const ContactDetailScreen({super.key, required this.contact});

 // lib/screens/contacts/contact_detail_screen.dart
// Update the build method to show more contact details
@override
Widget build(BuildContext context) {
  final authService = Provider.of<AuthService>(context);
  final apiService = Provider.of<ApiService>(context);
  final user = authService.currentUser;
  var size = MediaQuery.of(context).size;
  print('the image url is'); print(contact.imageUrl);

   bool isLocalImage = contact.imageUrl.isNotEmpty && 
        (contact.imageUrl.startsWith('/') || 
         contact.imageUrl.startsWith('file://'));
  
  return Scaffold(
    appBar: AppBar(
      title: Text('NUDGE', style: AppTextStyles.title3.copyWith(color: Color.fromRGBO(45, 161, 175, 1), fontFamily: 'RobotoMono'),),
                  centerTitle: true,
                  iconTheme: IconThemeData(color: Color.fromRGBO(45, 161, 175, 1)),
                  backgroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditContactScreen(contactId: contact.id),
              ),
            );
          },
        ),
        // IconButton(
        //   icon: const Icon(Icons.notifications),
        //   onPressed: () {
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(
        //         builder: (context) => const NotificationsScreen(),
        //       ),
        //     );
        //   },
        // ),

        IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              // NudgeService().sendTestNudge(contact, authService.currentUser!.uid);
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(content: Text('Test nudge sent for ${contact.name}')),
              // );
              apiService.triggerManualNudge(contact.id);
              // apiService.scheduleRegularNotifications();
            },
            tooltip: 'Send test nudge',
          ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                    radius: 50,
                    backgroundColor: Color.fromRGBO(45, 161, 175, 1),
                    backgroundImage: contact.imageUrl.isNotEmpty
                        ? isLocalImage
                            ? FileImage(File(contact.imageUrl.replaceFirst('file://', '')))
                            : NetworkImage(contact.imageUrl) as ImageProvider
                        : null,
                    child: contact.imageUrl.isEmpty 
                        ? const Icon(Icons.person, size: 40) 
                        : null,
                  ),
                const SizedBox(height: 15),
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                if (contact.profession != null && contact.profession!.isNotEmpty)
                  Text(
                    contact.profession!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // Contact Information Section
          const Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          
          if (contact.phoneNumber.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone', style: TextStyle(fontWeight: FontWeight.w600),),
              subtitle: Text(contact.phoneNumber),
            ),
          
          if (contact.email.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email', style: TextStyle(fontWeight: FontWeight.w600),),
              subtitle: Text(contact.email),
            ),
          
          // Connection Details Section
          const SizedBox(height: 20),
          const Text(
            'Connection Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Connection Type', style: TextStyle(fontWeight: FontWeight.w600),),
            subtitle: Text(contact.connectionType),
          ),

          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Contact Period', style: TextStyle(fontWeight: FontWeight.w600),),
            subtitle: Text(contact.period.toString()),
          ),
          
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Contact Frequency', style: TextStyle(fontWeight: FontWeight.w600),),
            subtitle: Text(contact.frequency.toString()),
          ),
          
          if (contact.socialGroups.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Social Groups', style: TextStyle(fontWeight: FontWeight.w600),),
              subtitle: Text(contact.socialGroups.join(', ')),
            ),
          
          if (contact.tags.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600),),
              subtitle: Wrap(
                spacing: 4,
                children: contact.tags.map((tag) => Chip(
                  label: Text(tag),
                  backgroundColor: const Color.fromRGBO(37, 150, 190, 0.2),
                )).toList(),
              ),
            ),

          const SizedBox(height: 24),
          const Text(
            'Smart Suggestions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SmartTaggingSuggestions(contact: contact),
          
          // Important Dates Section
          const SizedBox(height: 20),
          const Text(
            'Important Dates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          
          if (contact.birthday != null)
            ListTile(
              leading: const Icon(Icons.cake),
              title: const Text('Birthday'),
              subtitle: Text(DateFormat('MMMM d, y').format(contact.birthday!)),
            ),
          
          if (contact.anniversary != null)
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Anniversary'),
              subtitle: Text(DateFormat('MMMM d, y').format(contact.anniversary!)),
            ),
          
          if (contact.workAnniversary != null)
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('Work Anniversary'),
              subtitle: Text(DateFormat('MMMM d, y').format(contact.workAnniversary!)),
            ),
          
          // Notes Section
          if (contact.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(contact.notes),
          ],
          
          const SizedBox(height: 30),
          SizedBox(
            width: size.width,
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  if (user != null) {
                    final databaseService = DatabaseService(uid: user.uid);
                    databaseService.updateContact(contact.copyWith(
                      lastContacted: DateTime.now(),
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(45, 161, 175, 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Mark as Done', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color.fromRGBO(45, 161, 175, 1),
                  side: const BorderSide(
                    color: Color.fromRGBO(45, 161, 175, 1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Snooze Reminder'),
              ),
            ],
          ),
          )
        ],
      ),
    ),
  );
}
}