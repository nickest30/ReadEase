import 'package:flutter/foundation.dart';
import '../models/teacher.dart';

class TeacherProvider extends ChangeNotifier {
  Teacher? _currentTeacher;
  Teacher? get currentTeacher => _currentTeacher;
  bool get isLoggedIn => _currentTeacher != null;

  void setTeacher(Teacher teacher) {
    _currentTeacher = teacher;
    notifyListeners();
  }

  void logout() {
    _currentTeacher = null;
    notifyListeners();
  }
}