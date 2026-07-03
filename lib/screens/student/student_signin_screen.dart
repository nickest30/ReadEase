import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../services/database_service.dart';

class StudentSignInScreen extends StatefulWidget {
  const StudentSignInScreen({super.key});

  @override
  State<StudentSignInScreen> createState() =>
      _StudentSignInScreenState();
}

class _StudentSignInScreenState extends State<StudentSignInScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final student = await DatabaseService.instance
        .getStudentByUsername(_usernameController.text.trim());

    if (!mounted) return;

    if (student == null) {
      setState(() {
        _errorMessage = 'Username not found.';
        _isSubmitting = false;
      });
      return;
    }

    final isCorrect = BCrypt.checkpw(
      _passwordController.text,
      student.passwordHash,
    );

    if (!mounted) return;

    if (!isCorrect) {
      setState(() {
        _errorMessage = 'Incorrect password.';
        _isSubmitting = false;
      });
      return;
    }

    // On a new device, take them to Set PIN first
    Navigator.of(context).pushReplacementNamed(
      '/set-pin',
      arguments: student,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back,
                    color: Color(0xFF2E3A3A)),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign In',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),
              const Text(
                'Log in with your credentials',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Username',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _usernameController,
                decoration: _inputDecoration('Enter your username'),
              ),
              const SizedBox(height: 16),

              const Text(
                'Password',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration('Enter your password'),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
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
                  onPressed: _isSubmitting ? null : _handleSignIn,
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
                          'LOGIN',
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
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(
            color: Color(0xFF2BAFA0), width: 2),
      ),
    );
  }
}