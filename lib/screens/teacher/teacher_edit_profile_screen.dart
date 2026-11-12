import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/teacher_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';

class TeacherEditProfileScreen extends StatefulWidget {
  const TeacherEditProfileScreen({super.key});

  @override
  State<TeacherEditProfileScreen> createState() =>
      _TeacherEditProfileScreenState();
}

class _TeacherEditProfileScreenState extends State<TeacherEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _schoolNameController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final teacher = context.read<TeacherProvider>().currentTeacher;
    _fullNameController =
        TextEditingController(text: teacher?.fullName ?? '');
    _schoolNameController =
        TextEditingController(text: teacher?.schoolName ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final teacherProvider = context.read<TeacherProvider>();
    final teacher = teacherProvider.currentTeacher;
    if (teacher == null || teacher.id == null) return;

    final newName = _fullNameController.text.trim();
    final newSchool = _schoolNameController.text.trim();

    if (newName == teacher.fullName && newSchool == teacher.schoolName) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await DatabaseService.instance.updateTeacherProfile(
        teacher.id!,
        fullName: newName,
        schoolName: newSchool,
      );

      final refreshed =
          await DatabaseService.instance.getTeacherById(teacher.id!);
      if (!mounted) return;

      if (refreshed != null) {
        teacherProvider.setTeacher(refreshed);
      }

      if (teacher.firebaseUid != null && refreshed != null) {
        try {
          await FirestoreService.instance
              .saveTeacher(refreshed, teacher.firebaseUid!)
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('Cloud teacher save failed (continuing): $e');
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
      debugPrint('Teacher edit profile error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not save changes. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = context.watch<TeacherProvider>().currentTeacher;

    if (teacher == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/role-selection',
            (route) => false,
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.teacherBg,
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
                        'Update your display name and school',
                        style: AppText.caption,
                      ),
                    ],
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

            const _FieldLabel('School Name'),
            TextFormField(
              controller: _schoolNameController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              validator: Validators.schoolName,
              decoration: _inputDecoration(
                hint: 'Enter your school name',
                icon: Icons.school_rounded,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: AppColors.accentYellow.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Color(0xFF2C2C2C),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your username (${teacher.username}) cannot be changed here.',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2C2C),
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
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: const Color(0xFF2C2C2C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  elevation: 3,
                  shadowColor: AppColors.accentYellow.withValues(alpha: 0.4),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Color(0xFF2C2C2C),
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
                'assets/images/mascot/groo_creating.png',
                width: mascotSize,
                height: mascotSize,
                fit: BoxFit.contain,
                cacheWidth: (mascotSize * 2).toInt(),
                errorBuilder: (_, _, _) => Container(
                  width: mascotSize,
                  height: mascotSize,
                  decoration: BoxDecoration(
                    color: AppColors.accentYellow.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentYellow,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: mascotSize * 0.4,
                    color: const Color(0xFF2C2C2C),
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
      backgroundColor: AppColors.teacherBg,
      body: SafeArea(child: content),
    );
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
        borderSide: const BorderSide(color: AppColors.accentTeal, width: 2),
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