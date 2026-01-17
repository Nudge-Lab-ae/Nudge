// lib/screens/social_universe_immersive_screen.dart
import 'package:flutter/material.dart';
import 'package:nudge/models/contact.dart';
import 'package:nudge/providers/theme_provider.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/widgets/contact_detail_modal.dart';
import 'package:nudge/widgets/social_universe.dart';
import 'package:provider/provider.dart';

class SocialUniverseImmersiveScreen extends StatelessWidget {
  const SocialUniverseImmersiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiService = Provider.of<ApiService>(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamProvider<List<Contact>>.value(
      value: apiService.getContactsStream(),
      initialData: const [],
      child: Consumer<List<Contact>>(
        builder: (context, contacts, child) {
          return SocialUniverseWidget(
            contacts: contacts,
            onContactView: (contact) {
              // Use the same beautiful modal as dashboard
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                isScrollControlled: true,
                backgroundColor: Colors.white,
                builder: (context) {
                  return ContactDetailsModal(
                    contact: contact,
                    apiService: apiService,
                  );
                },
              );
            },
            isImmersive: true,
            isDarkMode: themeProvider.isDarkMode,
            onExitImmersive: () {
              Navigator.pop(context);
            },
          );
        },
      ),
    ));
  }
}