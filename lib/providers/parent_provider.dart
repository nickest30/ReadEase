import 'package:flutter/foundation.dart';
import '../models/parent.dart';

class ParentProvider extends ChangeNotifier {
  Parent? _currentParent;
  Parent? get currentParent => _currentParent;
  bool get isLoggedIn => _currentParent != null;

  void setParent(Parent parent) {
    _currentParent = parent;
    notifyListeners();
  }

  void logout() {
    _currentParent = null;
    notifyListeners();
  }
}