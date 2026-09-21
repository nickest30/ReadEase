import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/class_group.dart';
import '../../models/student.dart';
import '../../providers/teacher_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class ClassOverviewScreen extends StatefulWidget {
  const ClassOverviewScreen({super.key});

  @override
  State<ClassOverviewScreen> createState() => _ClassOverviewScreenState();
}

class _ClassOverviewScreenState extends State<ClassOverviewScreen> {
  List<Student> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStudents());
  }

  Future<void> _loadStudents() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final classGroup = args['classGroup'] as ClassGroup;
    final students = await DatabaseService.instance
        .getStudentsInClass(classGroup.id!);
    if (!mounted) return;
    setState(() {
      _students = students;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final classGroup = args['classGroup'] as ClassGroup;
    final teacher = context.watch<TeacherProvider>().currentTeacher;

    return Scaffold(
      backgroundColor: AppColors.teacherBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text('Class Overview', style: AppText.h2),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.sm),

                          // Groo teaching — centered
                          Image.asset(
                            'assets/images/mascot/groo_teaching.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                color: AppColors.accentYellow
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentYellow,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.class_rounded,
                                size: 72,
                                color: AppColors.accentYellow,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Class info card — full width below Groo
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadius.large),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppShadows.soft,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    classGroup.className,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Grade ${classGroup.gradeLevel}',
                                    style: AppText.caption,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.introBg,
                                      borderRadius: BorderRadius.circular(AppRadius.medium),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'JOIN CODE',
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.5,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          classGroup.joinCode,
                                          style: const TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textYellow,
                                            letterSpacing: 4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Action buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    label: 'Analytics',
                                    icon: Icons.bar_chart_rounded,
                                    onTap: () {
                                      if (teacher == null) return;
                                      Navigator.of(context).pushNamed(
                                        '/class-analytics',
                                        arguments: {
                                          'classGroup': classGroup,
                                          'students': _students,
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _ActionButton(
                                    label: 'Leaderboard',
                                    icon: Icons.leaderboard_rounded,
                                    onTap: () {
                                      Navigator.of(context).pushNamed(
                                        '/class-leaderboard',
                                        arguments: {
                                          'classGroup': classGroup,
                                          'students': _students,
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Enrolled students
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'ENROLLED STUDENTS (${_students.length})',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _students.isEmpty
                                    ? _buildEmpty()
                                    : Column(
                                        children: _students.map((student) {
                                          return _StudentRow(
                                            student: student,
                                            onTap: () {
                                              Navigator.of(context)
                                                  .pushNamed(
                                                '/teacher-student-progress',
                                                arguments: {
                                                  'classGroup': classGroup,
                                                  'student': student,
                                                },
                                              );
                                            },
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No students enrolled yet.\nShare the join code above with your class.',
        textAlign: TextAlign.center,
        style: AppText.caption,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accentYellow, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;

  const _StudentRow({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = student.displayName.isNotEmpty
        ? student.displayName[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.accentYellow,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.displayName,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Grade ${student.gradeLevel}',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            Text(
              '${student.totalPoints} pts',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textYellow,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}