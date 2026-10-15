import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/avatar_helper.dart';

class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({super.key});

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  late int _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final student = context.read<StudentProvider>().currentStudent;
    _selected = student?.avatarIndex ?? 1;
  }

  Future<void> _save() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student?.id == null) return;

    setState(() => _saving = true);

    await DatabaseService.instance
        .updateStudentAvatar(student!.id!, _selected);

    final refreshed =
        await DatabaseService.instance.getStudentById(student.id!);
    if (!mounted) return;

    if (refreshed != null) {
      context.read<StudentProvider>().updateStudent(refreshed);

      if (refreshed.firebaseUid != null && refreshed.firebaseUid!.isNotEmpty) {
        // 1. Push avatar to students/{uid} doc.
        try {
          await FirestoreService.instance.saveStudent(
            refreshed.firebaseUid!,
            refreshed.displayName,
            refreshed.gradeLevel,
            username: refreshed.username,
            avatarIndex: refreshed.avatarIndex,
            includePoints: false,
          );
        } catch (e) {
          debugPrint('🔥 avatar students-doc push failed: $e');
        }

        // 2. Trigger a full sync so leaderboard/{uid} picks up the new
        //    avatarIndex too. Without this, Class + Global tabs would
        //    still show the old value until the next quiz.
        if (mounted) {
          final connectivity = context.read<ConnectivityProvider>();
          final authProvider = context.read<AuthProvider>();
          unawaited(
            SyncService.instance.syncAll(
              student: refreshed,
              connectivity: connectivity,
              authProvider: authProvider,
            ),
          );
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choose Your Avatar', style: AppText.h2),
                        SizedBox(height: 2),
                        Text(
                          'Pick a character to represent you',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.95,
                ),
                itemCount: 12,
                itemBuilder: (context, i) {
                  final index = i + 1;
                  final isSelected = index == _selected;
                  return _AvatarTile(
                    index: index,
                    label: avatarLabels[index] ?? 'Avatar $index',
                    selected: isSelected,
                    onTap: () => setState(() => _selected = index),
                  );
                },
              ),
            ),

            // Save
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Selected: ${avatarLabels[_selected] ?? 'Avatar $_selected'}',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'SAVE',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  final int index;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.index,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(
                color: selected
                    ? AppColors.accentTeal
                    : AppColors.border,
                width: selected ? 3 : 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.accentTeal.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(4),
            child: Center(
              child: Image.asset(
                avatarAssetPath(index),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.accentTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}