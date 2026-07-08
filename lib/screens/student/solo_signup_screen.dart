import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../services/auth_service.dart';

class SoloSignupScreen extends StatefulWidget {
  const SoloSignupScreen({super.key});

  @override
  State<SoloSignupScreen> createState() => _SoloSignupScreenState();
}

class _SoloSignupScreenState extends State<SoloSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  int _selectedGrade = 1;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final existing = await DatabaseService.instance
          .getStudentByUsername(_usernameController.text.trim());

      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'That username is already taken.';
          _isSubmitting = false;
        });
        return;
      }

      final hashedPassword = BCrypt.hashpw(
        _passwordController.text,
        BCrypt.gensalt(),
      );

      // Attempt Firebase registration — works when online
      // Uses username@readease.app as a synthetic email
      // since Firebase Auth requires an email format
      final syntheticEmail =
          '${_usernameController.text.trim().toLowerCase()}@readease.app';

      String? firebaseUid;
      try {
        firebaseUid = await AuthService.instance.registerUser(
          syntheticEmail,
          _passwordController.text,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
      } catch (_) {
        firebaseUid = null;
      }

      final newStudent = Student(
        username: _usernameController.text.trim(),
        passwordHash: hashedPassword,
        displayName: _usernameController.text.trim(),
        gradeLevel: _selectedGrade,
        firebaseUid: firebaseUid,
        createdAt: DateTime.now().toIso8601String(),
      );

      final newId =
          await DatabaseService.instance.insertStudent(newStudent);

      if (!mounted) return;

      final createdStudent =
          await DatabaseService.instance.getStudentById(newId);

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '/set-pin',
        arguments: createdStudent,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E3A3A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fill in your details below',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: Color(0xFF6B7878),
                  ),
                ),
                const SizedBox(height: 24),

                _Label('Username'),
                TextFormField(
                  controller: _usernameController,
                  decoration: _fieldDecoration('Username'),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _Label('Grade Level'),
                Wrap(
                  spacing: 8,
                  children: List.generate(6, (index) {
                    final grade = index + 1;
                    final isSelected = _selectedGrade == grade;
                    return ChoiceChip(
                      label: Text('$grade'),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedGrade = grade);
                      },
                      selectedColor: const Color(0xFF2BAFA0),
                      labelStyle: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF2E3A3A),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                _Label('Password'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _fieldDecoration('Password'),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _Label('Confirm Password'),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: _fieldDecoration('Confirm Password'),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFF6F61),
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2BAFA0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'SIGN UP',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7878),
                      side: const BorderSide(color: Color(0xFFE9DCBE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'BACK',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9DCBE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9DCBE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2BAFA0), width: 2),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7878),
        ),
      ),
    );
  }
}