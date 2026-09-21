import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/parent.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../utils/app_theme.dart';

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

    final agreed = await _showTermsModal();
    if (!agreed || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();

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

      final firebaseUid = await authProvider.register(
        email,
        _passwordController.text,
      );

      if (!mounted) return;

      if (firebaseUid == null) {
        setState(() {
          _errorMessage =
              'Email is already registered or network failed. Try a different email.';
          _isSubmitting = false;
        });
        return;
      }

      final newParent = Parent(
        username: _usernameController.text.trim(),
        passwordHash: hashedPassword,
        fullName: _fullNameController.text.trim(),
        email: email,
        firebaseUid: firebaseUid,
        createdAt: DateTime.now().toIso8601String(),
      );

      final newId = await DatabaseService.instance.insertParent(newParent);
      if (!mounted) return;

      final createdParent =
          await DatabaseService.instance.getParentById(newId);
      if (!mounted || createdParent == null) return;

      parentProvider.setParent(createdParent);

      Navigator.of(context).pushReplacementNamed('/parent-dashboard');
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
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Terms and Data Privacy',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppColors.textPrimary,
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
                '• On this device by default. Cloud sync activates when you register.',
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
                'parent or guardian and agree to storage of this data. '
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
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
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
      backgroundColor: AppColors.parentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),

                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Header row with Motter
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Account', style: AppText.h1),
                          SizedBox(height: 2),
                          Text(
                            'Set up your parent profile',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/images/mascot/motter_welcoming.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentPurple,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          color: AppColors.accentPurple,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                _buildField('Full Name', _fullNameController,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null),

                const SizedBox(height: AppSpacing.md),

                _buildField('Username', _usernameController,
                    validator: (v) => v == null || v.trim().length < 3
                        ? 'At least 3 characters'
                        : null),

                const SizedBox(height: AppSpacing.md),

                _buildField('Email', _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter a valid email'
                        : null),

                const SizedBox(height: AppSpacing.md),

                _buildField('Password', _passwordController,
                    obscure: true,
                    validator: (v) => v == null || v.length < 6
                        ? 'At least 6 characters'
                        : null),

                const SizedBox(height: AppSpacing.md),

                _buildField('Confirm Password', _confirmController,
                    obscure: true,
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.textCoral,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
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

                const SizedBox(height: AppSpacing.xl),
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
            color: AppColors.textMuted,
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
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide:
                  const BorderSide(color: AppColors.accentPurple, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}