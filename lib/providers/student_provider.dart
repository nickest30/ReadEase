import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student.dart';
import '../services/database_service.dart';

class StudentProvider extends ChangeNotifier {
  static const _keyLastStudentId = 'session.lastStudentId';

  Student? _currentStudent;
  Student? get currentStudent => _currentStudent;
  bool get isLoggedIn => _currentStudent != null;

  bool _initialized = false;
  bool get initialized => _initialized;

  /// Loads the last-active student from disk so a cold start can route
  /// directly to PIN entry instead of the role selection.
  /// Safe to call multiple times — no-ops after the first run.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_keyLastStudentId);
      if (id != null) {
        final student = await DatabaseService.instance.getStudentById(id);
        if (student != null) {
          _currentStudent = student;
        } else {
          // Record was deleted — clear the stale key.
          await prefs.remove(_keyLastStudentId);
        }
      }
    } catch (e) {
      debugPrint('StudentProvider.init failed (non-blocking): $e');
    }
    _initialized = true;
    notifyListeners();
  }

  void setStudent(Student student) {
    _currentStudent = student;
    notifyListeners();
    _persistId(student.id);
  }

  void updateStudent(Student student) {
    _currentStudent = student;
    notifyListeners();
  }

  Future<void> logout() async {
    _currentStudent = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastStudentId);
    } catch (e) {
      debugPrint('StudentProvider.logout: could not clear id: $e');
    }
  }

  Future<void> _persistId(int? id) async {
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastStudentId, id);
    } catch (e) {
      debugPrint('StudentProvider: could not persist id: $e');
    }
  }
}