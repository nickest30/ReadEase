import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  List<Student> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChildren());
  }

  Future<void> _loadChildren() async {
    final parent = context.read<ParentProvider>().currentParent;
    if (parent == null) return;

    final children =
        await DatabaseService.instance.getChildrenOfParent(parent.id!);
    if (!mounted) return;
    setState(() {
      _children = children;
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
          'You can log back in anytime with your username and password.',
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
    context.read<ParentProvider>().logout();

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/parent-welcome',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>().currentParent;

    if (parent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/parent-welcome',
            (route) => false,
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.parentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Header with Motter
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${parent.fullName.split(' ').first}!',
                          style: AppText.h2,
                        ),
                        const SizedBox(height: 2),
                        const Text('My Children', style: AppText.caption),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/mascot/motter_base.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 70,
                      height: 70,
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
                        size: 34,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _children.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                              childAspectRatio: 0.95,
                            ),
                            itemCount: _children.length,
                            itemBuilder: (context, index) {
                              final child = _children[index];
                              return _ChildCard(
                                child: child,
                                onTap: () => Navigator.of(context).pushNamed(
                                  '/child-progress',
                                  arguments: {'child': child},
                                ),
                              );
                            },
                          ),
              ),

              if (_children.length < 4) ...[
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).pushNamed('/add-child');
                      _loadChildren();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Add Child',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

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
            'assets/images/mascot/motter_gentle.png',
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
                Icons.person_add_alt_rounded,
                size: 64,
                color: AppColors.accentPurple,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No children added yet',
            style: AppText.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Tap "Add Child" below to create\nyour first child profile.',
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

class _ChildCard extends StatelessWidget {
  final Student child;
  final VoidCallback onTap;

  const _ChildCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = child.displayName.isNotEmpty
        ? child.displayName[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.accentPurple,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              child.displayName,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Grade ${child.gradeLevel}',
              style: AppText.caption,
            ),
            const SizedBox(height: 4),
            Text(
              '${child.totalPoints} pts',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textYellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}