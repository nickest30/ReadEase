import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/class_group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _classNameController = TextEditingController();
  int _selectedGrade = 1;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateClass() async {
    if (_isSubmitting) return;
    final nameError = Validators.className(_classNameController.text);
    if (nameError != null) {
      setState(() => _errorMessage = nameError);
      return;
    }

    final teacherProvider = context.read<TeacherProvider>();
    final authProvider = context.read<AuthProvider>();
    final teacher = teacherProvider.currentTeacher;

    if (teacher == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final joinCode = DatabaseService.instance.generateJoinCode();

      final newGroup = ClassGroup(
        teacherId: teacher.id!,
        className: _classNameController.text.trim(),
        gradeLevel: _selectedGrade,
        joinCode: joinCode,
        createdAt: DateTime.now().toIso8601String(),
      );

      final localId = await DatabaseService.instance.insertClassGroup(newGroup);

      if (!mounted) return;

      final teacherUid = authProvider.uid;
      if (teacherUid == null) {
        setState(() {
          _errorMessage =
              'Not signed in to cloud. Log out and log back in with internet.';
          _isSubmitting = false;
        });
        return;
      }

      final firestoreId = await FirestoreService.instance.saveClassGroup(
        newGroup,
        teacherUid,
        teacherName: teacher.fullName,
      );

      if (!mounted) return;

      if (firestoreId.isEmpty) {
        setState(() {
          _errorMessage =
              'Class saved on device, but cloud sync failed. Students cannot join until you are online.';
          _isSubmitting = false;
        });
        return;
      }

      await DatabaseService.instance.updateClassGroupFirestoreId(
        localId,
        firestoreId,
      );

      debugPrint('Class synced: $firestoreId with code $joinCode');

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          backgroundColor: AppColors.surface,
          title: const Text(
            'Class Created!',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share this join code with your students:',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.introBg,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(
                    color: AppColors.accentYellow,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          joinCode,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textYellow,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      onPressed: () {
                        SfxService.tap();
                        Clipboard.setData(ClipboardData(text: joinCode));
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Join code copied',
                              style: TextStyle(fontFamily: 'Nunito'),
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      color: AppColors.textPrimary,
                      tooltip: 'Copy join code',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                SfxService.tap();
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
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
    final isTablet = Responsive.isTablet(context);
    final imgSize = Responsive.imageSize(context, base: 90);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 20,
      ),
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
                    Text('Create Class', style: AppText.h1),
                    SizedBox(height: 2),
                    Text(
                      'Set up a class group',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              Image.asset(
                'assets/images/mascot/groo_creating.png',
                width: imgSize,
                height: imgSize,
                fit: BoxFit.contain,
                cacheWidth: (imgSize * 2).toInt(),
                errorBuilder: (_, _, _) => Container(
                  width: imgSize,
                  height: imgSize,
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
                    color: AppColors.accentYellow,
                    size: imgSize * 0.45,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          const Text(
            'Class Name',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _classNameController,
            maxLength: 40,
            decoration: _inputDecoration('e.g. Grade 3 - Section A')
                .copyWith(counterText: ''),
          ),

          const SizedBox(height: AppSpacing.lg),

          const Text(
            'Grade Level',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

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
                onTap: () {
                  SfxService.tap();
                  setState(() => _selectedGrade = grade);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentYellow
                        : AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentYellow
                          : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Grade $grade',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
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
              onPressed: _isSubmitting
                  ? null
                  : () {
                      SfxService.tap();
                      _handleCreateClass();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.textPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'CREATE CLASS',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
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
        borderSide: const BorderSide(color: AppColors.accentYellow, width: 2),
      ),
    );
  }
}