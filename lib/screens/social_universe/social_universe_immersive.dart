// lib/screens/social_universe_immersive_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/widgets/social_universe.dart';
import 'package:provider/provider.dart';

class SocialUniverseImmersiveScreen extends StatefulWidget {
  const SocialUniverseImmersiveScreen({super.key});

  @override
  State<SocialUniverseImmersiveScreen> createState() => 
      _SocialUniverseImmersiveScreenState();
}

class _SocialUniverseImmersiveScreenState 
    extends State<SocialUniverseImmersiveScreen> {
  
  void _showContactQuickPanel(BuildContext context, Contact contact, ApiService apiService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        // You'll need to import or create this widget
        // For now, I'll use a placeholder
        return Container(
          height: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                contact.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text('Connection Type: ${contact.connectionType}'),
              Text('Last Contacted: ${contact.lastContacted}'),
              Text('VIP: ${contact.isVIP}'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    
    return StreamProvider<List<Contact>>.value(
      value: apiService.getContactsStream(),
      initialData: const [],
      child: Consumer<List<Contact>>(
        builder: (context, contacts, child) {
          return SocialUniverseWidget(
            contacts: contacts,
            onContactView: (contact) {
              _showContactQuickPanel(context, contact, apiService);
            },
            isImmersive: true,
            onExitImmersive: () {
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}