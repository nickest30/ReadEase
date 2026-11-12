import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/class_group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/email_verification_banner.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen>
    with WidgetsBindingObserver {
  List<ClassGroup> _classes = [];
  bool _loading = true;

  // Ash text used on top of yellow backgrounds for maximum readability
  static const Color _ashText = Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
      _checkEmailVerification();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerification();
    }
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

  Future<void> _checkEmailVerification() async {
    final teacher = context.read<TeacherProvider>().currentTeacher;
    if (teacher == null || teacher.firebaseUid == null) return;
    if (teacher.emailVerified) return;

    final connectivity = context.read<ConnectivityProvider>();
    if (!connectivity.isOnline) return;

    final authProvider = context.read<AuthProvider>();
    final verified = await authProvider.checkEmailVerified();
    if (!verified || !mounted) return;

    await DatabaseService.instance.markTeacherEmailVerified(teacher.id!);
    await FirestoreService.instance
        .markEmailVerified(teacher.firebaseUid!, 'teacher');

    final updated =
        await DatabaseService.instance.getTeacherById(teacher.id!);
    if (updated != null && mounted) {
      context.read<TeacherProvider>().setTeacher(updated);
    }
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
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop(false);
            },
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
              SfxService.tap();
              Navigator.of(ctx).pop(true);
            },
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

    final authProvider = context.read<AuthProvider>();
    final teacherProvider = context.read<TeacherProvider>();

    await authProvider.signOut();
    teacherProvider.logout();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/role-selection',
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
    final imgSize = Responsive.imageSize(context, base: 70);

    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

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
                width: imgSize,
                height: imgSize,
                fit: BoxFit.contain,
                cacheWidth: (imgSize * 2).toInt(),
                errorBuilder: (_, _, _) => Container(
                  width: imgSize,
                  height: imgSize,
                  // Yellow tint bg + ash icon = signature + visible
                  decoration: BoxDecoration(
                    color: AppColors.accentYellow.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentYellow,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: _ashText,
                    size: imgSize * 0.45,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          if (teacher.firebaseUid != null && !teacher.emailVerified)
            EmailVerificationBanner(
              // Keep yellow tint — banner text handles its own contrast
              accentColor: AppColors.accentYellow,
              role: 'teacher',
            ),

          const SizedBox(height: AppSpacing.sm),

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
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 2;
                          if (constraints.maxWidth > 600) {
                            crossAxisCount = 3;
                          }
                          if (constraints.maxWidth > 800) {
                            crossAxisCount = 4;
                          }

                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
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
                                  SfxService.tap();
                                  await Navigator.of(context).pushNamed(
                                    '/class-overview',
                                    arguments: {'classGroup': group},
                                  );
                                  _loadClasses();
                                },
                              );
                            },
                          );
                        },
                      ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Create Class: yellow bg + ash text (signature) ──
          SizedBox(
            height: Responsive.buttonHeight(context),
            child: ElevatedButton.icon(
              onPressed: () async {
                SfxService.tap();
                await Navigator.of(context).pushNamed('/create-class');
                _loadClasses();
              },
              icon: const Icon(Icons.add, color: _ashText),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Create Class',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: _ashText,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: _ashText,
                elevation: 2,
                shadowColor: AppColors.accentYellow.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Settings: teal foreground (was invisible yellow text) ──
          SizedBox(
            height: Responsive.buttonHeight(context),
            child: OutlinedButton.icon(
              onPressed: () {
                SfxService.tap();
                Navigator.of(context).pushNamed('/teacher-settings');
              },
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentTeal,
                side: const BorderSide(
                  color: AppColors.accentTeal,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          SizedBox(
            height: Responsive.buttonHeight(context),
            child: OutlinedButton(
              onPressed: () {
                SfxService.tap();
                _handleLogout();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textCoral,
                side: const BorderSide(color: AppColors.accentCoral),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Log Out',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.teacherBg,
      body: SafeArea(child: content),
    );
  }

  Widget _buildEmptyState() {
    final imgSize = Responsive.imageSize(context, base: 140);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/mascot/groo_gentle.png',
            width: imgSize,
            height: imgSize,
            fit: BoxFit.contain,
            cacheWidth: (imgSize * 2).toInt(),
            errorBuilder: (_, _, _) => Container(
              width: imgSize,
              height: imgSize,
              // Yellow tint bg + ash icon = visible
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: AppColors.accentYellow,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.class_rounded,
                size: imgSize * 0.45,
                color: _ashText,
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

class _ClassCard extends StatelessWidget {
  final ClassGroup group;
  final VoidCallback onTap;

  // Ash text on top of yellow tints for readability
  static const Color _ashText = Color(0xFF2C2C2C);

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
            // ── Icon tile: yellow tint bg + ash icon (was invisible) ──
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: const Icon(
                Icons.class_rounded,
                color: _ashText,
                size: 24,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
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
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Grade ${group.gradeLevel}',
                style: AppText.caption,
              ),
            ),
            const SizedBox(height: 4),
            // ── Join code: yellow tint bg + ash text (was yellow-on-yellow) ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentYellow.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  group.joinCode,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _ashText,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}