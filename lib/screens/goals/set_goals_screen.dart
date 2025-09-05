import 'package:flutter/material.dart';
import 'package:nudge/screens/notifications/notifications_screen.dart';
import '../contacts/search_screen.dart';
import '../../widgets/frequency_button.dart';

class SetGoalsScreen extends StatelessWidget {
  const SetGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NUDGE'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Goals',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Adjust the default level of how often you want to engage with each group of contacts.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const Text(
              'This can be edited later by group or person.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Family',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FrequencyButton(text: 'Monthly', isSelected: false),
                FrequencyButton(text: 'Quarterly', isSelected: false),
                FrequencyButton(text: 'Annually', isSelected: true, count: '4 times'),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Friends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FrequencyButton(text: 'Monthly', isSelected: false),
                FrequencyButton(text: 'Quarterly', isSelected: false),
                FrequencyButton(text: 'Annually', isSelected: true, count: '8 times'),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Clients',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FrequencyButton(text: 'Monthly', isSelected: false),
                FrequencyButton(text: 'Quarterly', isSelected: false),
                FrequencyButton(text: 'Annually', isSelected: true, count: '2 times'),
              ],
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(37, 150, 190, 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}