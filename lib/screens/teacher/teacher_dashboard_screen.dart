import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/class_group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<ClassGroup> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClasses());
  }

  Future<void> _loadClasses() async {
    final teacher = context.read<TeacherProvider>().currentTeacher;
    if (teacher == null) return;

    final classes = await DatabaseService.instance
        .getClassGroupsByTeacher(teacher.id!);
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _loading = false;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Log out?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Your classes stay saved. Log back in anytime.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
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
              backgroundColor: AppColors.accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    context.read<AuthProvider>().signOut();
    context.read<TeacherProvider>().logout();

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/teacher-welcome',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacher = context.watch<TeacherProvider>().currentTeacher;

    if (teacher == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/teacher-welcome',
            (route) => false,
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.teacherBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.teacherBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Header with Groo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${teacher.fullName.split(' ').first}!',
                          style: AppText.h2,
                        ),
                        const SizedBox(height: 2),
                        Text(teacher.schoolName, style: AppText.caption),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/mascot/groo_checking.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color:
                            AppColors.accentYellow.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentYellow,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: AppColors.accentYellow,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              const Text(
                'My Classes',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _classes.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                              childAspectRatio: 1.05,
                            ),
                            itemCount: _classes.length,
                            itemBuilder: (context, index) {
                              final group = _classes[index];
                              return _ClassCard(
                                group: group,
                                onTap: () async {
                                  await Navigator.of(context).pushNamed(
                                    '/class-overview',
                                    arguments: {'classGroup': group},
                                  );
                                  _loadClasses();
                                },
                              );
                            },
                          ),
              ),

              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).pushNamed('/create-class');
                    _loadClasses();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Create Class',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentYellow,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textCoral,
                    side: const BorderSide(color: AppColors.accentCoral),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/mascot/groo_gentle.png',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: const Icon(
                Icons.class_rounded,
                size: 64,
                color: AppColors.accentYellow,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No classes yet',
            style: AppText.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Tap "Create Class" below\nto set up your first class.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  final ClassGroup group;
  final VoidCallback onTap;

  const _ClassCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: const Icon(
                Icons.class_rounded,
                color: AppColors.accentYellow,
                size: 24,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              group.className,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Grade ${group.gradeLevel}',
              style: AppText.caption,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.introBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                group.joinCode,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textYellow,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}