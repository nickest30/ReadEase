import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../student/recovery_code_settings_screen.dart';
import '../../utils/avatar_helper.dart';

class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  Future<void> _confirmLogout() async {
    final studentProvider = context.read<StudentProvider>();
    final authProvider = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Log out?',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 18),
        ),
        content: const Text(
          'You can log back in with your PIN.',
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
                  fontFamily: 'Nunito', color: AppColors.textMuted),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await authProvider.signOut();
    studentProvider.logout();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/role-selection', (route) => false);
  }

  void _showColorBlindDialog(SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Color Blind Mode',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ColorBlindOption(
                label: 'None',
                value: 'none',
                selected: settings.colorBlindMode,
                onTap: () {
                  SfxService.tap();
                  settings.setColorBlindMode('none');
                  Navigator.of(ctx).pop();
                }),
            _ColorBlindOption(
                label: 'Deuteranopia (green-blind)',
                value: 'deuteranopia',
                selected: settings.colorBlindMode,
                onTap: () {
                  SfxService.tap();
                  settings.setColorBlindMode('deuteranopia');
                  Navigator.of(ctx).pop();
                }),
            _ColorBlindOption(
                label: 'Protanopia (red-blind)',
                value: 'protanopia',
                selected: settings.colorBlindMode,
                onTap: () {
                  SfxService.tap();
                  settings.setColorBlindMode('protanopia');
                  Navigator.of(ctx).pop();
                }),
            _ColorBlindOption(
                label: 'Tritanopia (blue-blind)',
                value: 'tritanopia',
                selected: settings.colorBlindMode,
                onTap: () {
                  SfxService.tap();
                  settings.setColorBlindMode('tritanopia');
                  Navigator.of(ctx).pop();
                }),
          ],
        ),
      ),
    );
  }

  String _colorBlindLabel(String mode) {
    switch (mode) {
      case 'deuteranopia':
        return 'Green-blind mode';
      case 'protanopia':
        return 'Red-blind mode';
      case 'tritanopia':
        return 'Blue-blind mode';
      default:
        return 'Off';
    }
  }

  String _textScaleLabel(double scale) {
    if (scale < 0.95) return 'Small';
    if (scale > 1.05) return 'Large';
    return 'Medium';
  }

  Future<bool> _checkLinkedStudent() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || !student.isLinked) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.family_restroom_rounded,
                color: AppColors.accentPurple, size: 24),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Managed by Parent',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'Your profile was created by your parent or guardian. They can see any changes you make here.\n\nDo you want to continue?',
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
                  fontFamily: 'Nunito', color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'I Understand',
              style: TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmUnlink() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.link_off_rounded,
                color: AppColors.accentCoral, size: 24),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Unlink from Parent?',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'Your parent will no longer see your reading progress on their dashboard.\n\nYou can link again later with a new code from your parent.',
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
                  fontFamily: 'Nunito', color: AppColors.textMuted),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Unlink',
              style: TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (student.firebaseUid != null) {
      try {
        await FirestoreService.instance
            .unlinkStudentFromParent(student.firebaseUid!);
      } catch (e) {
        debugPrint('unlink cloud failed (continuing): $e');
      }
    }

    await DatabaseService.instance
        .updateStudentParentUid(student.id!, '', false);
    if (!mounted) return;

    final refreshed =
        await DatabaseService.instance.getStudentById(student.id!);
    if (!mounted || refreshed == null) return;

    context.read<StudentProvider>().updateStudent(refreshed);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unlinked. Your progress is now private.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;
    final settings = context.watch<SettingsProvider>();

    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true)
              .pushNamedAndRemoveUntil('/role-selection', (route) => false);
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTablet = Responsive.isTablet(context);
    final avatarSize = Responsive.imageSize(context, base: 56);
    final yseSize = Responsive.imageSize(context, base: 80);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  SfxService.tap();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: AppText.h1),
                    SizedBox(height: 2),
                    Text('Adjust your preferences', style: AppText.caption),
                  ],
                ),
              ),
              _YseImage(
                assetPath: 'assets/images/mascot/yse_tinkering.png',
                size: yseSize,
                fallbackIcon: Icons.settings_suggest_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          GestureDetector(
            onTap: () async {
              SfxService.tap();
              final canProceed = await _checkLinkedStudent();
              if (!canProceed || !context.mounted) return;
              Navigator.of(context).pushNamed('/edit-profile');
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: const BoxDecoration(
                        color: AppColors.accentTeal, shape: BoxShape.circle),
                    child: ClipOval(
                      child: Image.asset(
                        avatarAssetPath(student.avatarIndex),
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                        cacheWidth: (avatarSize * 2).toInt(),
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            student.displayName.isNotEmpty
                                ? student.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            student.displayName,
                            style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Grade ${student.gradeLevel} • ${student.username}',
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_rounded, color: AppColors.accentTeal),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const Text(
            'AUDIO',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          _SettingCard(
            icon: Icons.music_note_rounded,
            iconColor: AppColors.accentOrange,
            label: 'Sound Effects',
            subtitle: 'Volume',
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: settings.sfxVolume,
                onChanged: (val) => settings.setSfxVolume(val),
                onChangeEnd: (_) => SfxService.tap(),
                activeColor: AppColors.accentOrange,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _SettingCard(
            icon: Icons.library_music_rounded,
            iconColor: AppColors.accentPurple,
            label: 'Background Music',
            subtitle: 'Volume',
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: settings.bgmVolume,
                onChanged: (val) => settings.setBgmVolume(val),
                activeColor: AppColors.accentPurple,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const Text(
            'ACCESSIBILITY',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          _SettingCard(
            icon: Icons.text_fields_rounded,
            iconColor: AppColors.accentPurple,
            label: 'Text Size',
            subtitle: _textScaleLabel(settings.textScale),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SizeButton(
                    label: 'A',
                    size: 12,
                    selected: settings.textScale == 0.85,
                    onTap: () {
                      SfxService.tap();
                      settings.setTextScale(0.85);
                    }),
                const SizedBox(width: 6),
                _SizeButton(
                    label: 'A',
                    size: 15,
                    selected: settings.textScale == 1.0,
                    onTap: () {
                      SfxService.tap();
                      settings.setTextScale(1.0);
                    }),
                const SizedBox(width: 6),
                _SizeButton(
                    label: 'A',
                    size: 18,
                    selected: settings.textScale == 1.15,
                    onTap: () {
                      SfxService.tap();
                      settings.setTextScale(1.15);
                    }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _SettingCard(
            icon: Icons.visibility_rounded,
            iconColor: AppColors.accentOrange,
            label: 'Color Blind Mode',
            subtitle: _colorBlindLabel(settings.colorBlindMode),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => _showColorBlindDialog(settings),
          ),
          const SizedBox(height: AppSpacing.xl),

          const Text(
            'PROFILE & CONNECTIONS',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          _SettingCard(
            icon: Icons.face_rounded,
            iconColor: AppColors.accentOrange,
            label: 'Avatar',
            subtitle: 'Choose your look',
            trailing: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                avatarAssetPath(student.avatarIndex),
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                cacheWidth: 88,
                errorBuilder: (_, _, _) => const Icon(Icons.face_rounded,
                    size: 32, color: AppColors.textMuted),
              ),
            ),
            onTap: () async {
              final changed =
                  await Navigator.of(context).pushNamed('/avatar-picker');
              if (changed == true && mounted) setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.md),

          _SettingCard(
            icon: Icons.group_add_rounded,
            iconColor: AppColors.accentTeal,
            label: 'Join a Class',
            subtitle: student.className != null
                ? 'Currently in: ${student.className}'
                : 'Enter your teacher\'s code',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => Navigator.of(context).pushNamed('/join-class'),
          ),
          const SizedBox(height: AppSpacing.md),

          if (!student.isLinked)
            _SettingCard(
              icon: Icons.family_restroom_rounded,
              iconColor: AppColors.accentPurple,
              label: 'Link to Parent',
              subtitle: 'Enter a code from your parent',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: () => Navigator.of(context).pushNamed('/link-parent'),
            )
          else
            _SettingCard(
              icon: Icons.link_off_rounded,
              iconColor: AppColors.accentCoral,
              label: 'Unlink from Parent',
              subtitle: 'Stop sharing progress with your parent',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: _confirmUnlink,
            ),
          const SizedBox(height: AppSpacing.md),

          if (!student.isLinked) ...[
            _SettingCard(
              icon: Icons.key_rounded,
              iconColor: AppColors.accentOrange,
              label: 'Recovery Code',
              subtitle: (student.recoveryCodeHash != null &&
                      student.recoveryCodeHash!.isNotEmpty)
                  ? 'Active'
                  : 'Not set up yet',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: () {
                SfxService.tap();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecoveryCodeSettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          _SettingCard(
            icon: Icons.lock_rounded,
            iconColor: AppColors.accentPurple,
            label: 'Change PIN',
            subtitle: 'Update your 4-digit PIN',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () async {
              final canProceed = await _checkLinkedStudent();
              if (!canProceed || !context.mounted) return;
              Navigator.of(context).pushNamed('/change-pin');
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          SizedBox(
            height: Responsive.buttonHeight(context),
            child: OutlinedButton.icon(
              onPressed: () {
                SfxService.tap();
                _confirmLogout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Log Out',
                  style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textCoral,
                side: const BorderSide(color: AppColors.accentCoral),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
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
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.medium)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(subtitle, style: AppText.caption),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: () {
          SfxService.tap();
          onTap!();
        },
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: card,
      );
    }

    return card;
  }
}

class _SizeButton extends StatelessWidget {
  final String label;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  const _SizeButton({
    required this.label,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? AppColors.accentPurple : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
              color: selected ? AppColors.accentPurple : AppColors.border),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textMuted)),
        ),
      ),
    );
  }
}

class _ColorBlindOption extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _ColorBlindOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentTeal.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.small)),
        child: Row(
          children: [
            Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.accentTeal : AppColors.textMuted,
                size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.textPrimary))),
          ],
        ),
      ),
    );
  }
}

class _YseImage extends StatelessWidget {
  final String assetPath;
  final double size;
  final IconData fallbackIcon;

  const _YseImage(
      {required this.assetPath,
      required this.size,
      required this.fallbackIcon});

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
              border: Border.all(color: AppColors.border, width: 2)),
          child: Center(
              child: Icon(fallbackIcon,
                  size: size * 0.5, color: AppColors.accentTeal)),
        );
      },
    );
  }
}