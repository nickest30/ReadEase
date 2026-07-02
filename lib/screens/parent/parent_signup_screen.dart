import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../models/parent.dart';
import '../../services/database_service.dart';

class ParentSignupScreen extends StatefulWidget {
  const ParentSignupScreen({super.key});

  @override
  State<ParentSignupScreen> createState() => _ParentSignupScreenState();
}

class _ParentSignupScreenState extends State<ParentSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    // Show terms modal first — only proceed if agreed
    final agreed = await _showTermsModal();
    if (!agreed) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final existing = await DatabaseService.instance
          .getParentByUsername(_usernameController.text.trim());

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

      final newParent = Parent(
        username: _usernameController.text.trim(),
        passwordHash: hashedPassword,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      );

      final newId =
          await DatabaseService.instance.insertParent(newParent);

      if (!mounted) return;

      final createdParent =
          await DatabaseService.instance.getParentById(newId);

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '/parent-dashboard',
        arguments: createdParent,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  Future<bool> _showTermsModal() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Terms and Data Privacy',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ReadEase keeps your child\'s data private and safe.',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'What we collect:',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                '• Name and grade (to personalize lessons)\n'
                '• Reading progress and badges',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
              ),
              SizedBox(height: 10),
              Text(
                'Where it stays:',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                '• On this device only. Never uploaded without consent.',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
              ),
              SizedBox(height: 10),
              Text(
                'Your consent:',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                'By tapping "I Agree", you confirm that you are the '
                'parent or guardian and agree to local data storage. '
                'This app complies with Republic Act 10173 '
                '(Data Privacy Act of 2012).',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: Color(0xFF6B7878),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5FBF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'I Agree',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Parent Account',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E3A3A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set up your account to monitor your child\'s progress',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: Color(0xFF6B7878),
                  ),
                ),
                const SizedBox(height: 24),

                _buildField('Full Name', _fullNameController,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Required'
                        : null),
                const SizedBox(height: 14),
                _buildField('Username', _usernameController,
                    validator: (v) =>
                        v == null || v.trim().length < 3
                            ? 'At least 3 characters'
                            : null),
                const SizedBox(height: 14),
                _buildField('Email', _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v == null || !v.contains('@')
                            ? 'Enter a valid email'
                            : null),
                const SizedBox(height: 14),
                _buildField('Password', _passwordController,
                    obscure: true,
                    validator: (v) =>
                        v == null || v.length < 6
                            ? 'At least 6 characters'
                            : null),
                const SizedBox(height: 14),
                _buildField('Confirm Password', _confirmController,
                    obscure: true,
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null),

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

                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5FBF),
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
                            'CREATE ACCOUNT',
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

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7878),
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
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
                  color: Color(0xFF8B5FBF), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}