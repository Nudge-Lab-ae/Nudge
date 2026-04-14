import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProvider extends ChangeNotifier {
  bool _isAdmin = false;
  bool _isLoading = true;
  
  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Initialize and cache admin status
  Future<void> checkAndCacheAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isAdmin = false;
      _isLoading = false;
      notifyListeners();
      return;
    }
    
    try {
      print(_isAdmin); print(' is the current admin statujs');
      final doc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();
      
      _isAdmin = doc.exists;
      print(_isAdmin); print(' is the admin statujs');
    } catch (e) {
      print('Error checking admin status: $e');
      _isAdmin = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Optional: Refresh admin status if needed
  Future<void> refreshAdminStatus() async {
    _isLoading = true;
    notifyListeners();
    await checkAndCacheAdminStatus();
  }
}