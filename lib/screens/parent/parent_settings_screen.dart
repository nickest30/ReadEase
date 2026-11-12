import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatting.dart';
import '../../widgets/about_modal.dart';
import '../shared/account_security_screen.dart';
import 'parent_edit_profile_screen.dart';

class ParentSettingsScreen extends StatelessWidget {
  const ParentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>().currentParent;
    if (parent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/role-selection',
            (route) => false,
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.parentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTablet = Responsive.isTablet(context);
    final imgSize = Responsive.imageSize(context, base: 70);

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
                    Text('Manage your account', style: AppText.caption),
                  ],
                ),
              ),
              Image.asset(
                'assets/images/mascot/motter_base.png',
                width: imgSize,
                height: imgSize,
                fit: BoxFit.contain,
                cacheWidth: (imgSize * 2).toInt(),
                errorBuilder: (_, _, _) => Icon(
                  Icons.settings_rounded,
                  size: imgSize * 0.6,
                  color: AppColors.accentPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

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
                    color: AppColors.accentPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      parent.fullName.isNotEmpty
                          ? parent.fullName[0].toUpperCase()
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          parent.fullName,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          parent.username,
                          style: AppText.caption,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          maskEmail(parent.email),
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _SettingCard(
            icon: Icons.edit_rounded,
            iconColor: AppColors.accentPurple,
            label: 'Edit Profile',
            subtitle: 'Change display name and username',
            onTap: () {
              SfxService.tap();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ParentEditProfileScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),

          _SettingCard(
            icon: Icons.shield_outlined,
            iconColor: AppColors.accentPurple,
            label: 'Account & Security',
            subtitle: 'Change password, phone, backup code',
            onTap: () {
              SfxService.tap();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const AccountSecurityScreen(role: 'parent'),
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),

          _SettingCard(
            icon: Icons.key_rounded,
            iconColor: AppColors.accentOrange,
            label: 'Change Password',
            subtitle: 'Send a reset link to your email',
            onTap: () {
              SfxService.tap();
              _confirmChangePassword(context);
            },
          ),

          const SizedBox(height: AppSpacing.md),

          _SettingCard(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.accentTeal,
            label: 'About ReadEase',
            subtitle: 'Version, developers, privacy',
            onTap: () {
              SfxService.tap();
              AboutModal.show(context);
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          SizedBox(
            height: Responsive.buttonHeight(context),
            child: OutlinedButton.icon(
              onPressed: () {
                SfxService.tap();
                _confirmLogout(context);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Log Out',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
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
      backgroundColor: AppColors.parentBg,
      body: SafeArea(child: content),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();
    final navigator = Navigator.of(context);

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

    if (confirmed != true || !context.mounted) return;

    await authProvider.signOut();
    parentProvider.logout();

    if (!context.mounted) return;
    navigator.pushNamedAndRemoveUntil(
      '/role-selection',
      (route) => false,
    );
  }

  Future<void> _confirmChangePassword(BuildContext context) async {
    final parent = context.read<ParentProvider>().currentParent;
    if (parent == null) return;

    final authProvider = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Change Password',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Text(
          'We\'ll send a password reset link to '
          '${maskEmail(parent.email)}.\n\n'
          'Open the email and follow the instructions to set a new '
          'password. Then log out and log back in with your new password.',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13),
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
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Send Link',
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

    final ok = await authProvider.sendPasswordResetEmail(parent.email);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Reset link sent. Check your inbox.'
              : 'Could not send the reset link. Try again later.',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}