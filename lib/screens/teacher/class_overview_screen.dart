import 'package:flutter/material.dart';

import '../../models/class_group.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import 'package:provider/provider.dart';

class ClassOverviewScreen extends StatefulWidget {
  const ClassOverviewScreen({super.key});

  @override
  State<ClassOverviewScreen> createState() => _ClassOverviewScreenState();
}

class _ClassOverviewScreenState extends State<ClassOverviewScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStudents());
  }

  Future<void> _loadStudents() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final classGroup = args['classGroup'] as ClassGroup;

    // Fast-fail when offline
    if (!context.read<ConnectivityProvider>().isOnline) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'You\'re offline. Connect to view enrolled students.';
      });
      return;
    }

    // Class must be synced to Firestore to have enrollments
    if (classGroup.firestoreId == null || classGroup.firestoreId!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'This class isn\'t synced to the cloud yet. Students can\'t join.';
      });
      return;
    }

    final students = await FirestoreService.instance
        .getEnrolledStudentsDetailed(classGroup.firestoreId!);

    if (!mounted) return;
    setState(() {
      _students = students;
      _loading = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final classGroup = args['classGroup'] as ClassGroup;

    return Scaffold(
      backgroundColor: AppColors.teacherBg,
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
                  : RefreshIndicator(
                      onRefresh: _loadStudents,
                      color: AppColors.accentYellow,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.sm),

                            // Groo teaching
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

                            // Class info card
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xl),
                              child: _buildClassInfoCard(classGroup),
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
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
                                  if (_errorMessage != null)
                                    _buildError()
                                  else if (_students.isEmpty)
                                    _buildEmpty()
                                  else
                                    ..._students.map((student) {
                                      return _StudentRow(
                                        student: student,
                                        onTap: () {
                                          // Navigate to student progress (Phase 2)
                                        },
                                      );
                                    }),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassInfoCard(ClassGroup classGroup) {
    return Container(
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
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: AppColors.accentCoral.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.accentCoral,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textCoral,
              ),
            ),
          ),
        ],
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
      child: Column(
        children: [
          Image.asset(
            'assets/images/mascot/groo_gentle.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'No students enrolled yet',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Share the join code above with your class.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────

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
  final Map<String, dynamic> student;
  final VoidCallback onTap;

  const _StudentRow({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (student['studentName'] as String?) ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final grade = student['gradeLevel'] ?? 0;
    final points = student['totalPoints'] ?? 0;
    final badges = student['badgeCount'] ?? 0;

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
              width: 40,
              height: 40,
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
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Grade $grade',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            if (badges > 0) ...[
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.accentYellow,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$badges',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textYellow,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              '$points pts',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textYellow,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}