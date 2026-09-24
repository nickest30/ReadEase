import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  Future<void> _confirmExit(BuildContext context) async {
    final studentProvider = context.read<StudentProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Exit?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to exit?\nProgress will be saved.',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'No',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
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
              'Yes',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Clear the session
    studentProvider.logout();

    // Return to profile list, clearing stack
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/student-profile-list',
      ModalRoute.withName('/role-selection'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;

    // Guard: no session → redirect to profile list
    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/student-profile-list',
            ModalRoute.withName('/role-selection'),
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(student: student),
              const SizedBox(height: 24),

              _HomeCard(
                icon: Icons.menu_book_rounded,
                label: 'Start Learning',
                sublabel: 'Pick a grade and lesson',
                color: AppColors.accentCoral,
                onTap: () => Navigator.of(context).pushNamed(
                  '/grade-selection',
                  arguments: student,
                ),
              ),
              const SizedBox(height: 12),
              _HomeCard(
                icon: Icons.emoji_events_rounded,
                label: 'My Badges',
                sublabel: 'See what you earned',
                color: AppColors.accentYellow,
                onTap: () => Navigator.of(context).pushNamed(
                  '/badges',
                  arguments: student,
                ),
              ),
              const SizedBox(height: 12),
              _HomeCard(
                icon: Icons.bar_chart_rounded,
                label: 'Progress',
                sublabel: 'Track your journey',
                color: AppColors.accentTeal,
                onTap: () => Navigator.of(context).pushNamed(
                  '/progress',
                  arguments: student,
                ),
              ),
              const SizedBox(height: 12),
              _HomeCard(
                icon: Icons.leaderboard_rounded,
                label: 'Leaderboard',
                sublabel: 'See your ranking',
                color: AppColors.accentPurple,
                onTap: () => Navigator.of(context).pushNamed(
                  '/leaderboard',
                  arguments: student,
                ),
              ),
              const SizedBox(height: 12),
              _HomeCard(
                icon: Icons.settings_rounded,
                label: 'Settings',
                sublabel: 'Edit profile and audio',
                color: AppColors.textMuted,
                onTap: () => Navigator.of(context).pushNamed(
                  '/settings',
                  arguments: student,
                ),
              ),

              const Spacer(),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _confirmExit(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCoral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save & Exit',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Student student;
  const _Header({required this.student});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.accentTeal,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${student.displayName}!',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${student.totalPoints} points earned',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}