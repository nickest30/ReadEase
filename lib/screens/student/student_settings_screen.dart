import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';

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
          'You can log back in with your PIN.',
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

    await authProvider.signOut();
    studentProvider.logout();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/student-profile-list',
      (route) => false,
    );
  }

  void _showColorBlindDialog(SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Color Blind Mode',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ColorBlindOption(
              label: 'None',
              value: 'none',
              selected: settings.colorBlindMode,
              onTap: () {
                settings.setColorBlindMode('none');
                Navigator.of(ctx).pop();
              },
            ),
            _ColorBlindOption(
              label: 'Deuteranopia (green-blind)',
              value: 'deuteranopia',
              selected: settings.colorBlindMode,
              onTap: () {
                settings.setColorBlindMode('deuteranopia');
                Navigator.of(ctx).pop();
              },
            ),
            _ColorBlindOption(
              label: 'Protanopia (red-blind)',
              value: 'protanopia',
              selected: settings.colorBlindMode,
              onTap: () {
                settings.setColorBlindMode('protanopia');
                Navigator.of(ctx).pop();
              },
            ),
            _ColorBlindOption(
              label: 'Tritanopia (blue-blind)',
              value: 'tritanopia',
              selected: settings.colorBlindMode,
              onTap: () {
                settings.setColorBlindMode('tritanopia');
                Navigator.of(ctx).pop();
              },
            ),
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

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;
    final settings = context.watch<SettingsProvider>();

    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/student-profile-list',
            (route) => false,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Header row with Yse tinkering
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                        Text('Adjust your preferences',
                            style: AppText.caption),
                      ],
                    ),
                  ),
                  _YseImage(
                    assetPath: 'assets/images/mascot/yse_tinkering.png',
                    size: 80,
                    fallbackIcon: Icons.settings_suggest_rounded,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Profile card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.accentTeal,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          student.displayName.isNotEmpty
                              ? student.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.displayName,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Grade ${student.gradeLevel} • ${student.username}',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showComingSoonSnack(
                        context,
                        'Edit Profile is coming in the next update!',
                      ),
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.accentTeal,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // AUDIO
              _SettingCard(
                icon: Icons.volume_up_rounded,
                iconColor: AppColors.accentTeal,
                label: 'Audio',
                subtitle: settings.audioEnabled
                    ? 'Sound effects on'
                    : 'Sound effects off',
                trailing: Switch(
                  value: settings.audioEnabled,
                  onChanged: (value) => settings.setAudioEnabled(value),
                  activeThumbColor: AppColors.accentTeal,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // TEXT SIZE
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
                      onTap: () => settings.setTextScale(0.85),
                    ),
                    const SizedBox(width: 6),
                    _SizeButton(
                      label: 'A',
                      size: 15,
                      selected: settings.textScale == 1.0,
                      onTap: () => settings.setTextScale(1.0),
                    ),
                    const SizedBox(width: 6),
                    _SizeButton(
                      label: 'A',
                      size: 18,
                      selected: settings.textScale == 1.15,
                      onTap: () => settings.setTextScale(1.15),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // COLOR BLIND MODE
              _SettingCard(
                icon: Icons.visibility_rounded,
                iconColor: AppColors.accentOrange,
                label: 'Color Blind Mode',
                subtitle: _colorBlindLabel(settings.colorBlindMode),
                trailing: IconButton(
                  onPressed: () => _showColorBlindDialog(settings),
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // CHANGE PIN (placeholder until next drop)
              _SettingCard(
                icon: Icons.lock_rounded,
                iconColor: AppColors.accentPurple,
                label: 'Change PIN',
                subtitle: 'Update your 4-digit PIN',
                trailing: IconButton(
                  onPressed: () => _showComingSoonSnack(
                    context,
                    'Change PIN is coming in the next update!',
                  ),
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // LOG OUT
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textCoral,
                    side: const BorderSide(color: AppColors.accentCoral),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Nunito')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final Widget trailing;

  const _SettingCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
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
            color: selected ? AppColors.accentPurple : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
          ),
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
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.accentTeal : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
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
  final IconData fallbackIcon;

  const _YseImage({
    required this.assetPath,
    required this.size,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
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
          child: Center(
            child: Icon(
              fallbackIcon,
              size: size * 0.5,
              color: AppColors.accentTeal,
            ),
          ),
        );
      },
    );
  }
}