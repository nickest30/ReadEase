import 'package:flutter/foundation.dart';
import '../models/student.dart';

class StudentProvider extends ChangeNotifier {
  Student? _currentStudent;
  Student? get currentStudent => _currentStudent;
  bool get isLoggedIn => _currentStudent != null;

  void setStudent(Student student) {
    _currentStudent = student;
    notifyListeners();
  }

  void updateStudent(Student student) {
    _currentStudent = student;
    notifyListeners();
  }

  void logout() {
    _currentStudent = null;
    notifyListeners();
  }
}