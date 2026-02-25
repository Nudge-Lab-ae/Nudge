import 'package:flutter/material.dart';

class FeedbackProvider extends ChangeNotifier {
  bool _isFabMenuOpen = false;
  
  bool get isFabMenuOpen => _isFabMenuOpen;
  
  void setFabMenuState(bool isOpen) {
    if (_isFabMenuOpen != isOpen) {
      _isFabMenuOpen = isOpen;
      notifyListeners();
    }
  }
  
  void toggleFabMenu() {
    _isFabMenuOpen = !_isFabMenuOpen;
    notifyListeners();
  }
}