import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/avatar_helper.dart';

class ProfileListScreen extends StatefulWidget {
  const ProfileListScreen({super.key});

  @override
  State<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends State<ProfileListScreen> {
  List<Student> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final students = await DatabaseService.instance.getAllStudents();
    if (!mounted) return;
    setState(() {
      _profiles = students;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final imgSize = Responsive.imageSize(context, base: 90);

    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          IconButton(
            onPressed: () {
              SfxService.tap();
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/role-selection',
                  (route) => false,
                );
              }
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
                    Text("Who's reading\ntoday?", style: AppText.h1),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Pick your profile to start',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              _YseImage(
                assetPath: 'assets/images/mascot/yse_thinking.png',
                size: imgSize,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _profiles.isEmpty
                    ? _buildEmptyState()
                    : _buildProfileGrid(),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: Responsive.buttonHeight(context),
            child: ElevatedButton.icon(
              onPressed: () {
                SfxService.tap();
                Navigator.of(context).pushNamed('/solo-signup');
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Register on Your Own',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: Responsive.buttonHeight(context),
            child: OutlinedButton.icon(
              onPressed: () {
                SfxService.tap();
                Navigator.of(context).pushNamed('/student-signin');
              },
              icon: const Icon(Icons.login_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Log In with Credentials',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentTeal,
                side: const BorderSide(color: AppColors.accentTeal, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
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
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: content),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.person_outline_rounded,
            size: 64,
            color: AppColors.textMuted,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'No profiles yet.',
            style: AppText.h2,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Tap "Register on Your Own"\nto create your first profile.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.95,
      ),
      itemCount: _profiles.length,
      itemBuilder: (context, index) {
        final student = _profiles[index];
        return _ProfileCard(
          student: student,
          onTap: () => Navigator.of(context).pushNamed(
            '/pin-entry',
            arguments: student,
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;

  const _ProfileCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarSize = Responsive.imageSize(context, base: 68);

    return InkWell(
      onTap: () {
        SfxService.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentTeal.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  avatarAssetPath(student.avatarIndex),
                  fit: BoxFit.cover,
                  cacheWidth: (avatarSize * 2).toInt(),
                  errorBuilder: (_, _, _) {
                    final initial = student.displayName.isNotEmpty
                        ? student.displayName[0].toUpperCase()
                        : '?';
                    return Container(
                      color: AppColors.accentTeal,
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                student.displayName,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Grade ${student.gradeLevel}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTeal,
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

class _YseImage extends StatelessWidget {
  final String assetPath;
  final double size;

  const _YseImage({required this.assetPath, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      cacheWidth: (size * 2).toInt(),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Icon(
            Icons.auto_stories_rounded,
            size: size * 0.5,
            color: AppColors.accentTeal,
          ),
        );
      },
    );
  }
}