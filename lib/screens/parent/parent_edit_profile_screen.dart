import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/parent_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';

class ParentEditProfileScreen extends StatefulWidget {
  const ParentEditProfileScreen({super.key});

  @override
  State<ParentEditProfileScreen> createState() =>
      _ParentEditProfileScreenState();
}

class _ParentEditProfileScreenState extends State<ParentEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final parent = context.read<ParentProvider>().currentParent;
    _fullNameController =
        TextEditingController(text: parent?.fullName ?? '');
    _usernameController =
        TextEditingController(text: parent?.username ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final parentProvider = context.read<ParentProvider>();
    final parent = parentProvider.currentParent;
    if (parent == null || parent.id == null) return;

    final newName = _fullNameController.text.trim();
    final newUsername = _usernameController.text.trim().toLowerCase();

    if (newName == parent.fullName && newUsername == parent.username) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (newUsername != parent.username) {
        final existing = await DatabaseService.instance
            .getParentByUsername(newUsername);
        if (existing != null && existing.id != parent.id) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'That username is already taken.';
            _isSaving = false;
          });
          return;
        }
      }

      await DatabaseService.instance.updateParentProfile(
        parent.id!,
        fullName: newName,
        username: newUsername,
      );

      final refreshed =
          await DatabaseService.instance.getParentById(parent.id!);
      if (!mounted) return;

      if (refreshed != null) {
        parentProvider.setParent(refreshed);
      }

      if (parent.firebaseUid != null && refreshed != null) {
        try {
          await FirestoreService.instance
              .saveParent(
                parentUid: parent.firebaseUid!,
                username: refreshed.username,
                fullName: refreshed.fullName,
                email: refreshed.email,
                phoneNumber: refreshed.phoneNumber,
                phoneVerified: refreshed.phoneVerified,
                emailVerified: refreshed.emailVerified,
              )
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('Cloud parent save failed (continuing): $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated!',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Parent edit profile error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not save changes. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>().currentParent;

    if (parent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/role-selection',
            (route) => false,
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.parentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTablet = Responsive.isTablet(context);
    final mascotSize = Responsive.imageSize(context, base: 150);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),

            IconButton(
              onPressed: () {
                SfxService.tap();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
                      Text('Edit Profile', style: AppText.h1),
                      SizedBox(height: 2),
                      Text(
                        'Update your name and username',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/images/mascot/motter_presenting.png',
                  width: mascotSize * 0.65,
                  height: mascotSize * 0.65,
                  fit: BoxFit.contain,
                  cacheWidth: (mascotSize * 0.65 * 2).toInt(),
                  errorBuilder: (_, _, _) => Icon(
                    Icons.edit_note_rounded,
                    size: mascotSize * 0.5,
                    color: AppColors.accentPurple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            const _FieldLabel('Full Name'),
            TextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: Validators.displayName,
              decoration: _inputDecoration(
                hint: 'Enter your full name',
                icon: Icons.person_rounded,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            const _FieldLabel('Username'),
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.done,
              validator: Validators.username,
              decoration: _inputDecoration(
                hint: 'Your username',
                icon: Icons.alternate_email_rounded,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: AppColors.accentPurple.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.accentPurple,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your email (${_maskEmail(parent.email)}) is managed by '
                      'Firebase and cannot be changed here. Contact support '
                      'if you need to update it.',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
              height: Responsive.buttonHeight(context),
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        SfxService.tap();
                        _save();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  elevation: 3,
                  shadowColor: AppColors.accentPurple.withValues(alpha: 0.4),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            Center(
              child: Image.asset(
                'assets/images/mascot/motter_presenting.png',
                width: mascotSize,
                height: mascotSize,
                fit: BoxFit.contain,
                cacheWidth: (mascotSize * 2).toInt(),
                errorBuilder: (_, _, _) => Container(
                  width: mascotSize,
                  height: mascotSize,
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentPurple,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: mascotSize * 0.4,
                    color: AppColors.accentPurple,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(child: content),
    );
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final local = parts[0];
    final domain = parts[1];
    final localMasked = local.length <= 2
        ? '${local[0]}***'
        : '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}';
    return '$localMasked@$domain';
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
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