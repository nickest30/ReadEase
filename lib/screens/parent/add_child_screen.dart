import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/parent_provider.dart';
import '../../services/credential_storage.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  int _selectedGrade = 1;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleAddChild() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pinController.text.length != 4) {
      setState(() => _errorMessage = 'PIN must be exactly 4 digits.');
      return;
    }

    // ── Capture providers BEFORE any await ──
    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();
    final connectivity = context.read<ConnectivityProvider>();
    final parent = parentProvider.currentParent;
    final parentUid = authProvider.uid;

    if (parent == null || parentUid == null) {
      setState(() => _errorMessage = 'Not signed in as parent.');
      return;
    }

    // Parent credentials should be in secure storage from signup/login
    Map<String, String>? parentCreds =
        await CredentialStorage.instance.read(parentUid);

    if (parentCreds == null) {
      if (!mounted) return;

      final password = await _promptForPassword(parent.fullName, parent.email);
      if (password == null || !mounted) return;

      // Save credentials and retry
      await authProvider.saveCredentials(
        uid: parentUid,
        email: parent.email,
        password: password,
      );

      parentCreds = await CredentialStorage.instance.read(parentUid);
      if (parentCreds == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Could not verify. Please try again.';
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final childUsername = _usernameController.text.trim().toLowerCase();
    final childPassword = _passwordController.text;
    final childEmail = '$childUsername@readease.app';

    String? childFirebaseUid;

    try {
      // 1. Check local uniqueness
      final existing = await DatabaseService.instance
          .getStudentByUsername(childUsername);
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'That username is already taken on this device.';
          _isSubmitting = false;
        });
        return;
      }

      // 2. Try to create Firebase account for child (only when online)
      if (connectivity.isOnline) {
        try {
          childFirebaseUid = await authProvider.register(
            childEmail,
            childPassword,
          );

          // ⚠️ At this point, Firebase has signed OUT the parent
          //    and signed IN the child. We must re-sign the parent.

          if (childFirebaseUid != null) {
            // Save child's credentials
            await authProvider.saveCredentials(
              uid: childFirebaseUid,
              email: childEmail,
              password: childPassword,
            );
          }

          // 3. Restore parent session (regardless of success)
          await authProvider.signIn(
            parentCreds['email']!,
            parentCreds['password']!,
          );

          debugPrint('🔑 Parent session restored');
        } catch (e) {
          debugPrint('⚠️ Child Firebase creation failed: $e');
          // Restore parent session even on failure
          await authProvider.signIn(
            parentCreds['email']!,
            parentCreds['password']!,
          );
          childFirebaseUid = null;
        }
      }

      if (!mounted) return;

      // 4. Save child locally (always)
      final hashedPassword = BCrypt.hashpw(childPassword, BCrypt.gensalt());
      final hashedPin = BCrypt.hashpw(_pinController.text, BCrypt.gensalt());

      final newChild = Student(
        username: childUsername,
        passwordHash: hashedPassword,
        displayName: _displayNameController.text.trim(),
        gradeLevel: _selectedGrade,
        pinHash: hashedPin,
        isLinked: true,
        parentId: parent.id,
        firebaseUid: childFirebaseUid,
        createdAt: DateTime.now().toIso8601String(),
      );

      await DatabaseService.instance.insertLinkedStudent(newChild);

      if (!mounted) return;

      // 5. Save child to Firestore with parentId (if we have a UID)
      if (childFirebaseUid != null) {
        await FirestoreService.instance.saveLinkedChild(
          childUid: childFirebaseUid,
          username: newChild.username,
          displayName: newChild.displayName,
          gradeLevel: newChild.gradeLevel,
          parentUid: parentUid,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      // On any error, ensure parent is signed back in
      try {
        await authProvider.signIn(
          parentCreds['email']!,
          parentCreds['password']!,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSubmitting = false;
      });
    }
  }


  Future<String?> _promptForPassword(String parentName, String email) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Confirm Password',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi $parentName, please enter your password to '
              'confirm adding a child.',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Your password',
                filled: true,
                fillColor: AppColors.parentBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isEmpty) return;
              Navigator.of(ctx).pop(controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return result;
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

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Child Profile', style: AppText.h1),
                          SizedBox(height: 2),
                          Text(
                            'Create an account for your child',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/images/mascot/motter_caring.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color:
                              AppColors.accentPurple.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentPurple,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.child_care_rounded,
                          color: AppColors.accentPurple,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                _FieldLabel('Display Name'),
                TextFormField(
                  controller: _displayNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Child\'s name'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                _FieldLabel('Username'),
                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration('Username for login'),
                  validator: (v) {
                    if (v == null || v.trim().length < 3) {
                      return 'At least 3 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                      return 'Only letters, numbers, underscores';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                _FieldLabel('Grade Level'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: List.generate(6, (index) {
                    final grade = index + 1;
                    final isSelected = _selectedGrade == grade;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedGrade = grade),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentPurple
                              : AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.medium),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentPurple
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Grade $grade',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: AppSpacing.md),

                _FieldLabel('Password'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration('At least 6 characters'),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'At least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                _FieldLabel('4-digit PIN'),
                TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('4-digit PIN'),
                  validator: (v) {
                    if (v == null || v.length != 4) {
                      return 'PIN must be exactly 4 digits';
                    }
                    return null;
                  },
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
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
                    onPressed: _isSubmitting ? null : _handleAddChild,
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
                            'ADD CHILD',
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
        borderSide: const BorderSide(color: AppColors.accentPurple, width: 2),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}