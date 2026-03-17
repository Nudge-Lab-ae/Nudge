// contact_detail_screen.dart - Updated with StreamBuilder for real-time updates
import 'dart:io';
import 'dart:math';
// import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nudge/providers/feedback_provider.dart';
import 'package:nudge/screens/contacts/edit_contact_screen.dart';
// import 'package:nudge/screens/dashboard/dashboard_screen.dart';
import 'package:nudge/services/api_service.dart';
import 'package:nudge/services/auth_service.dart';
import 'package:nudge/services/message_service.dart';
import 'package:nudge/theme/text_styles.dart';
// import 'package:nudge/widgets/add_touchpoint_modal.dart';
import 'package:nudge/widgets/feedback_floating_button.dart';
import 'package:nudge/widgets/log_interaction_modal.dart';
import 'package:provider/provider.dart';
import '../../models/contact.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:confetti/confetti.dart';

class ContactDetailScreen extends StatefulWidget {
  final Contact contact;
  final bool showConfetti;
  final Function? navigate;
  
  const ContactDetailScreen({super.key, required this.contact, this.showConfetti = false, this.navigate});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  bool _isUpdatingVIP = false;
  late ConfettiController _confettiController; // Add this
  bool _showConfetti = false; 

  @override
  void initState() {
    super.initState();
     _confettiController = ConfettiController(duration: const Duration(seconds: 8));
    
    // Check if we should show confetti (newly created contact)
    if (widget.showConfetti) {
      // Small delay to ensure the UI is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showConfetti = true;
        });
        _confettiController.play();

        // Flushbar(
        //   padding: EdgeInsets.all(10), borderRadius: BorderRadius.zero, duration: Duration(seconds: 2),
        //   flushbarPosition: FlushbarPosition.TOP, dismissDirection: FlushbarDismissDirection.HORIZONTAL,
        //   forwardAnimationCurve: Curves.fastLinearToSlowEaseIn, 
        //   backgroundColor: Colors.green,
        //   messageText: Center(
        //       child: Text('Successfully added contact', style: TextStyle(fontFamily: 'OpenSans', fontSize: 14,
        //           color: Colors.white, fontWeight: FontWeight.w400),)),
        // ).show(context);

        TopMessageService().showMessage(
                  context: context,
                  message: 'Successfully added contact!',
                  backgroundColor: Colors.green,
                  icon: Icons.check_circle,
                );
        
        // Auto-hide confetti after animation
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showConfetti = false;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose(); // Add this
    super.dispose();
  }

  Future<void> _toggleVIPStatus(bool isVIP, Contact contact) async {
    if (_isUpdatingVIP) return;
    
    setState(() {
      _isUpdatingVIP = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final updatedContact = contact.copyWith(isVIP: isVIP);
        await apiService.updateContact(updatedContact);
        
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(isVIP ? 'Added to Favourites' : 'Removed from Favourites')),
        // );
        TopMessageService().showMessage(
          context: context,
          message: isVIP ? 'Added to Favourites' : 'Removed from Favourites',
          backgroundColor: Colors.green,
          icon: Icons.check,
        );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error updating Favourites status: $e')),
      // );
       TopMessageService().showMessage(
          context: context,
          message: 'Error updating Favourites status: $e',
          backgroundColor: Colors.deepOrange,
          icon: Icons.error,
        );
    } finally {
      setState(() {
        _isUpdatingVIP = false;
      });
    }
  }

  String _getContactInitials(String name) {
    if (name.isEmpty) return '?';
    
    // Trim and split the name by spaces
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.length >= 2) {
      // Has at least first and last name - get first letter of first and last name
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    } else if (parts.length == 1) {
      // Only first name available
      return parts.first[0].toUpperCase();
    }
    
    return '?';
  }

  Color _getRingColor(String ring) {
    switch (ring) {
      case 'inner':
        return Colors.amber;
      case 'middle':
        return const Color(0xff3CB3E9);
      case 'outer':
        return const Color(0xff897ED6);
      default:
        return Colors.grey;
    }
  }

  IconData _getRingIcon(String ring) {
    switch (ring) {
      case 'inner':
        return Icons.star;
      case 'middle':
        return Icons.circle;
      case 'outer':
        return Icons.circle_outlined;
      default:
        return Icons.circle;
    }
  }

  String _getFormattedRingName(String ring) {
    switch (ring) {
      case 'inner':
        return 'Inner Circle';
      case 'middle':
        return 'Middle Circle';
      case 'outer':
        return 'Outer Circle';
      default:
        return 'Unknown';
    }
  }

  int getRandomIndex(String seed) {
    if (seed.isEmpty) return 1;
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return (hash.abs() % 6) + 1;
  }

  Future<void> _showLogInteractionModal(BuildContext context, ThemeProvider themeProvider, Contact contact) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: themeProvider.getSurfaceColor(context),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: LogInteractionModal(
            apiService: apiService,
            contact: contact,
            isDarkMode: themeProvider.isDarkMode,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiService = Provider.of<ApiService>(context);
    final feedbackProvider = Provider.of<FeedbackProvider>(context);
    var width = MediaQuery.of(context).size.width;
    
    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 20, right: 6),
        child: FeedbackFloatingButton(),
      ),
      body: Stack(
                children: [
                  Scaffold(
                    appBar: AppBar(
                title: Text(
                  'Contact Details', 
                  style: AppTextStyles.title2.copyWith(
                    color: themeProvider.getTextPrimaryColor(context), 
                    fontSize: 22, 
                    fontWeight: FontWeight.w800, 
                    fontFamily: 'Inter'
                  )
                ),
                centerTitle: true,
                leading: IconButton(
                  onPressed: (){
                    Navigator.pop(context);
                    if (widget.showConfetti){
                      widget.navigate!();
                    }
                  },
                  icon: Icon(Icons.arrow_back, color: themeProvider.getTextPrimaryColor(context))),
                iconTheme: IconThemeData(color: AppTheme.primaryColor),
                backgroundColor: themeProvider.getSurfaceColor(context),
                surfaceTintColor: Colors.transparent,
                actions: [
                  MaterialButton(
                    padding: EdgeInsets.zero,
                    child: Icon(Icons.edit, color: themeProvider.getTextPrimaryColor(context)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditContactScreen(contactId: widget.contact.id),
                        ),
                      );
                    },
                    onLongPress: () {
                      apiService.sendTestBirthdayNotification(widget.contact);
                      // apiService.sendTestEventNotification();
                    },
                  ),
                ],
              ),
            body: StreamBuilder<List<Contact>>(
        stream: apiService.getContactsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading contact',
                    style: TextStyle(color: themeProvider.getTextPrimaryColor(context)),
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            );
          }
          
          // Find the current contact in the updated list
          final currentContact = snapshot.data!.firstWhere(
            (c) => c.id == widget.contact.id,
            orElse: () => widget.contact,
          );
          
          return _buildContactDetails(context, themeProvider, currentContact);
        },
      )),
      if (feedbackProvider.isFabMenuOpen)
                  GestureDetector(
                    onTap: () {
                      // Optional: Close the menu when tapping the overlay
                      // You'll need to access the FeedbackFloatingButton's state
                      // This is handled automatically if the button listens to provider changes
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.55),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),

                  if (_showConfetti)
                  SizedBox(
                    width: width,
                    child: Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              numberOfParticles: 50,
              blastDirection: pi*1.3,
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
                  )
    ]),
    );
  }

  Widget _buildContactDetails(BuildContext context, ThemeProvider themeProvider, Contact contact) {
    final initials = _getContactInitials(contact.name);
    
    bool isLocalImage = contact.imageUrl.isNotEmpty && 
        (contact.imageUrl.startsWith('/') || 
         contact.imageUrl.startsWith('file://'));

    // bool hasNoInfo = contact.phoneNumber.isEmpty &&
    //     contact.email.isEmpty &&
    //     contact.notes.isEmpty &&
    //     contact.birthday == null &&
    //     contact.anniversary == null &&
    //     contact.workAnniversary == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.01),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.transparent,
                    backgroundImage: contact.imageUrl.isNotEmpty
                        ? isLocalImage
                            ? FileImage(File(contact.imageUrl.replaceFirst('file://', '')))
                            : NetworkImage(contact.imageUrl) as ImageProvider
                        : AssetImage('assets/contact-icons/${getRandomIndex(contact.id)}.png') as ImageProvider,
                    child: contact.imageUrl.isEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: AssetImage('assets/contact-icons/${getRandomIndex(contact.id)}.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                contact.name.isNotEmpty ? initials.toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontFamily: 'OpenSans',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'OpenSans',
                    fontWeight: FontWeight.bold,
                    color: themeProvider.getTextPrimaryColor(context)
                  ),
                ),
                const SizedBox(height: 5),
                if (contact.profession != null && contact.profession!.isNotEmpty)
                  Text(
                    contact.profession!,
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenSans',
                      color: themeProvider.getTextSecondaryColor(context),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // Favourites Toggle
          Card(
            color: themeProvider.getCardColor(context),
            child: ListTile(
              leading: Icon(Icons.star, color: contact.isVIP ? Colors.amber : themeProvider.getTextSecondaryColor(context)),
              title: Text(
                'Favourites', 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  color: themeProvider.getTextPrimaryColor(context), 
                  fontFamily: 'OpenSans'
                )
              ),
              subtitle: Text(
                contact.isVIP 
                    ? 'This contact is in your Favourites' 
                    : 'Add to your Favourites for special attention',
                style: TextStyle(color: themeProvider.getTextSecondaryColor(context), fontFamily: 'OpenSans')
              ),
              trailing: _isUpdatingVIP
                  ? SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        color: AppTheme.primaryColor
                      )
                    )
                  : Switch(
                      value: contact.isVIP,
                      onChanged: (value) => _toggleVIPStatus(value, contact),
                      activeColor: AppTheme.primaryColor,
                      inactiveThumbColor: themeProvider.getButtonColor(context),
                    ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // CDI Ring Display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _getRingColor(contact.computedRing).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getRingColor(contact.computedRing).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getRingIcon(contact.computedRing),
                  size: 16,
                  color: _getRingColor(contact.computedRing),
                ),
                const SizedBox(width: 8),
                Text(
                  _getFormattedRingName(contact.computedRing),
                  style: TextStyle(
                    color: _getRingColor(contact.computedRing),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'OpenSans',
                  ),
                ),
                // if (contact.cdi > 0) ...[
                //   const SizedBox(width: 12),
                //   Text(
                //     'CDI: ${contact.cdi.toStringAsFixed(0)}',
                //     style: TextStyle(
                //       color: themeProvider.getTextSecondaryColor(context),
                //       fontSize: 12,
                //       fontFamily: 'OpenSans',
                //     ),
                //   ),
                // ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Contact Information Section
          if (contact.phoneNumber.isNotEmpty || contact.email.isNotEmpty) ...[
            Text(
              'CONTACT INFORMATION',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.bold,
                color: themeProvider.getTextSecondaryColor(context),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            
            if (contact.phoneNumber.isNotEmpty)
              ListTile(
                leading: Icon(Icons.phone, color: themeProvider.getTextPrimaryColor(context)),
                title: Text(
                  'Phone', 
                  style: TextStyle(
                    fontWeight: FontWeight.w600, 
                    color: themeProvider.getTextPrimaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
                subtitle: Text(
                  contact.phoneNumber, 
                  style: TextStyle(
                    color: themeProvider.getTextSecondaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
              ),
            
            if (contact.email.isNotEmpty)
              ListTile(
                leading: Icon(Icons.email, color: themeProvider.getTextPrimaryColor(context)),
                title: Text(
                  'Email', 
                  style: TextStyle(
                    fontWeight: FontWeight.w600, 
                    color: themeProvider.getTextPrimaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
                subtitle: Text(
                  contact.email, 
                  style: TextStyle(
                    color: themeProvider.getTextSecondaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
              ),
            const SizedBox(height: 20),
          ],
          
          // Connection Details Section
          Text(
            'CONNECTION DETAILS',
            style: TextStyle(
              fontSize: 17,
              fontFamily: 'OpenSans',
              fontWeight: FontWeight.bold,
              color: themeProvider.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 10),
          
          ListTile(
            leading: SvgPicture.asset(
              'assets/contact-icons/connection-type.svg',
              width: 22,
              height: 22,
              color: themeProvider.getTextPrimaryColor(context)
            ),
            title: Text(
              'Connection Type', 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                color: themeProvider.getTextPrimaryColor(context), 
                fontFamily: 'OpenSans'
              )
            ),
            subtitle: Text(
              contact.connectionType, 
              style: TextStyle(
                color: themeProvider.getTextSecondaryColor(context), 
                fontFamily: 'OpenSans'
              )
            ),
          ),

          ListTile(
            leading: Icon(Icons.schedule, color: themeProvider.getTextPrimaryColor(context)),
            title: Text(
              'Contact Frequency', 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                color: themeProvider.getTextPrimaryColor(context), 
                fontFamily: 'OpenSans'
              )
            ),
            subtitle: Text(
              FrequencyPeriodMapper.getConversationalChoice(contact.frequency, contact.period),
              style: TextStyle(
                color: themeProvider.getTextSecondaryColor(context), 
                fontFamily: 'OpenSans'
              )
            ),
          ),
          
          if (contact.socialGroups.isNotEmpty)
            ListTile(
              leading: Icon(Icons.group, color: themeProvider.getTextPrimaryColor(context)),
              title: Text(
                'Social Groups', 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  color: themeProvider.getTextPrimaryColor(context), 
                  fontFamily: 'OpenSans'
                )
              ),
              subtitle: Text(
                contact.socialGroups.join(', '), 
                style: TextStyle(
                  color: themeProvider.getTextSecondaryColor(context), 
                  fontFamily: 'OpenSans'
                )
              ),
            ),
          
          // Important Dates Section
          if (contact.birthday != null || contact.anniversary != null || contact.workAnniversary != null) ...[
            const SizedBox(height: 20),
            Text(
              'IMPORTANT DATES',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.bold,
                color: themeProvider.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 10),
            
            if (contact.birthday != null)
              ListTile(
                leading: Icon(Icons.cake, color: themeProvider.getTextPrimaryColor(context)),
                title: Text(
                  'Birthday', 
                  style: TextStyle(
                    color: themeProvider.getTextPrimaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
                subtitle: Text(
                  DateFormat('MMMM d, y').format(contact.birthday!), 
                  style: TextStyle(
                    color: themeProvider.getTextSecondaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
              ),
            
            if (contact.anniversary != null)
              ListTile(
                leading: Icon(Icons.favorite, color: themeProvider.getTextPrimaryColor(context)),
                title: Text(
                  'Anniversary', 
                  style: TextStyle(
                    color: themeProvider.getTextPrimaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
                subtitle: Text(
                  DateFormat('MMMM d, y').format(contact.anniversary!), 
                  style: TextStyle(
                    color: themeProvider.getTextSecondaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
              ),
            
            if (contact.workAnniversary != null)
              ListTile(
                leading: Icon(Icons.work, color: themeProvider.getTextPrimaryColor(context)),
                title: Text(
                  'Work Anniversary', 
                  style: TextStyle(
                    color: themeProvider.getTextPrimaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
                subtitle: Text(
                  DateFormat('MMMM d, y').format(contact.workAnniversary!), 
                  style: TextStyle(
                    color: themeProvider.getTextSecondaryColor(context), 
                    fontFamily: 'OpenSans'
                  )
                ),
              ),
          ],
          
          // Notes Section
          if (contact.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Notes',
              style: TextStyle(
                color: themeProvider.getTextPrimaryColor(context),
                fontSize: 18,
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              contact.notes, 
              style: TextStyle(
                color: themeProvider.getTextSecondaryColor(context), 
                fontFamily: 'OpenSans'
              )
            ),
          ],
          
          // Contextual message when no info
          // if (hasNoInfo) ...[
          //   const SizedBox(height: 30),
          //   Container(
          //     padding: const EdgeInsets.all(16),
          //     decoration: BoxDecoration(
          //       color: themeProvider.getCardColor(context),
          //       borderRadius: BorderRadius.circular(10),
          //       border: Border.all(color: themeProvider.getTextHintColor(context)),
          //     ),
          //     child: Column(
          //       children: [
          //         Icon(Icons.info, size: 40, color: themeProvider.getTextSecondaryColor(context)),
          //         const SizedBox(height: 10),
          //         Text(
          //           'Add more details to this contact for better insights.',
          //           style: TextStyle(
          //             fontSize: 16,
          //             fontFamily: 'OpenSans',
          //             color: themeProvider.getTextSecondaryColor(context),
          //             fontStyle: FontStyle.italic,
          //           ),
          //           textAlign: TextAlign.center,
          //         ),
          //       ],
          //     ),
          //   ),
          // ],
          
          const SizedBox(height: 30),
          
          // Log Interaction Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showLogInteractionModal(context, themeProvider, contact);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'LOG INTERACTION',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenSans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}


