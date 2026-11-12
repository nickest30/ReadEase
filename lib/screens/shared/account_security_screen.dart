import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../providers/parent_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/backup_code.dart';
import '../../utils/formatting.dart';
import '../shared/backup_code_screen.dart';

class AccountSecurityScreen extends StatefulWidget {
  final String role;

  const AccountSecurityScreen({super.key, required this.role});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool _busy = false;
  String? _errorMessage;

  bool get _isParent => widget.role == 'parent';

  /// Ash text — used on top of yellow backgrounds for contrast
  static const Color _ashText = Color(0xFF2C2C2C);

  /// Signature color for BACKGROUNDS (yellow for teacher — on-brand)
  Color get _signatureBg =>
      _isParent ? AppColors.accentPurple : AppColors.accentYellow;

  /// Foreground color used ON signature backgrounds (white on purple, ash on yellow)
  Color get _signatureFg => _isParent ? Colors.white : _ashText;

  /// Action color for ICONS and TEXT buttons (must be visible on light bg)
  /// Parent: purple is fine. Teacher: yellow is invisible → use teal.
  Color get _actionColor =>
      _isParent ? AppColors.accentPurple : AppColors.accentTeal;

  Color get _bg => _isParent ? AppColors.parentBg : AppColors.teacherBg;

  String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('63') && digits.length == 12) return '+$digits';
    if (digits.startsWith('0') && digits.length == 11) {
      return '+63${digits.substring(1)}';
    }
    if (digits.length == 10) return '+63$digits';
    return null;
  }

  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    final ccEnd = phone.startsWith('+63')
        ? 3
        : (phone.startsWith('+') ? 2 : 0);
    final cc = phone.substring(0, ccEnd);
    final last4 = phone.substring(phone.length - 4);
    return '$cc *** $last4';
  }

  /// Add/change phone — NO OTP, saves with phoneVerified: false.
  /// SMS OTP is planned for a future version.
  Future<void> _changePhone() async {
    final parent = context.read<ParentProvider>().currentParent;
    final teacher = context.read<TeacherProvider>().currentTeacher;
    final uid = _isParent ? parent?.firebaseUid : teacher?.firebaseUid;
    final id = _isParent ? parent?.id : teacher?.id;

    if (id == null) {
      setState(() => _errorMessage = 'Session expired. Please log in again.');
      return;
    }

    final controller = TextEditingController();

    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Add Phone Number',
          style: AppText.h2.copyWith(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your PH phone number. SMS verification is not '
              'available yet — we\'ll save this number for future use.',
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: '9123456789',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 6),
                  child: Text(
                    '+63',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                filled: true,
                fillColor: AppColors.studentBg,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: BorderSide(color: _actionColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop();
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
              Navigator.of(ctx).pop(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              // Signature yellow + ash text = readable
              backgroundColor: _signatureBg,
              foregroundColor: _signatureFg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (input == null || input.isEmpty || !mounted) return;

    final normalized = _normalizePhone(input);
    if (normalized == null) {
      setState(() => _errorMessage =
          'Invalid number. Use format like 9123456789.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      // Best-effort cloud save (unverified — SMS OTP is future work)
      if (uid != null) {
        try {
          await FirestoreService.instance
              .updatePhoneNumber(
                uid: uid,
                role: widget.role,
                phoneNumber: normalized,
                verified: false,
              )
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('Cloud phone save failed (continuing): $e');
        }
      }

      // Local save
      if (_isParent) {
        await DatabaseService.instance
            .updateParentPhone(id, normalized, false);
        final updated =
            await DatabaseService.instance.getParentById(id);
        if (updated != null && mounted) {
          context.read<ParentProvider>().setParent(updated);
        }
      } else {
        await DatabaseService.instance
            .updateTeacherPhone(id, normalized, false);
        final updated =
            await DatabaseService.instance.getTeacherById(id);
        if (updated != null && mounted) {
          context.read<TeacherProvider>().setTeacher(updated);
        }
      }

      if (!mounted) return;
      setState(() => _busy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone number saved. SMS verification coming soon.',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Save phone error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = 'Could not save phone number. Try again.';
      });
    }
  }

  /// Regenerate backup code — NO phone required, NO OTP.
  Future<void> _regenerateBackupCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Generate New Backup Code?',
          style: AppText.h2.copyWith(fontSize: 18),
        ),
        content: const Text(
          'Your current backup code will stop working. A new one will '
          'be generated and shown only once.',
          style: AppText.caption,
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
              backgroundColor: _signatureBg,
              foregroundColor: _signatureFg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Generate',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final parent = context.read<ParentProvider>().currentParent;
    final teacher = context.read<TeacherProvider>().currentTeacher;
    final uid = _isParent ? parent?.firebaseUid : teacher?.firebaseUid;
    final id = _isParent ? parent?.id : teacher?.id;

    if (id == null) return;

    setState(() => _busy = true);

    final newCode = BackupCode.generate();
    final newHash = BCrypt.hashpw(newCode, BCrypt.gensalt());

    // Save to cloud (best-effort)
    if (uid != null) {
      try {
        await FirestoreService.instance
            .rotateBackupCode(uid, widget.role, newHash)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Cloud backup code rotation failed (continuing): $e');
      }
    }

    // Save locally
    try {
      if (_isParent) {
        await DatabaseService.instance
            .updateParentBackupCodeHash(id, newHash);
      } else {
        await DatabaseService.instance
            .updateTeacherBackupCodeHash(id, newHash);
      }
    } catch (e) {
      debugPrint('Local backup code save failed: $e');
    }

    if (!mounted) return;
    setState(() => _busy = false);

    // Show the new code
    await BackupCodeDialog.show(
      context,
      code: newCode,
      // Teal for teacher so code text/icons are visible in the dialog
      accentColor: _actionColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _isParent
        ? context.watch<ParentProvider>().currentParent?.email ?? ''
        : context.watch<TeacherProvider>().currentTeacher?.email ?? '';

    final emailVerified = _isParent
        ? (context.watch<ParentProvider>().currentParent?.emailVerified ??
            false)
        : (context.watch<TeacherProvider>().currentTeacher?.emailVerified ??
            false);

    final phone = _isParent
        ? context.watch<ParentProvider>().currentParent?.phoneNumber
        : context.watch<TeacherProvider>().currentTeacher?.phoneNumber;

    final phoneVerified = _isParent
        ? (context.watch<ParentProvider>().currentParent?.phoneVerified ??
            false)
        : (context.watch<TeacherProvider>().currentTeacher?.phoneVerified ??
            false);

    final isTablet = Responsive.isTablet(context);

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
                child: Text('Account & Security', style: AppText.h2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accentCoral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: AppColors.accentCoral.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.accentCoral, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppText.caption.copyWith(
                        color: AppColors.textCoral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          _SectionCard(
            icon: Icons.alternate_email_rounded,
            iconColor: _actionColor,
            title: 'Email',
            subtitle: email.isEmpty ? 'Not set' : maskEmail(email),
            trailing: emailVerified
                ? const _VerifiedBadge()
                : const _UnverifiedBadge(),
          ),
          const SizedBox(height: AppSpacing.md),

          _SectionCard(
            icon: Icons.phone_rounded,
            iconColor: _actionColor,
            title: 'Phone Number',
            subtitle: phone == null || phone.isEmpty
                ? 'Not set'
                : _maskPhone(phone),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (phone != null && phone.isNotEmpty)
                  phoneVerified
                      ? const _VerifiedBadge()
                      : const _UnverifiedBadge(),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          SfxService.tap();
                          _changePhone();
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: _actionColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    phone == null || phone.isEmpty ? 'Add' : 'Change',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _SectionCard(
            icon: Icons.key_rounded,
            iconColor: _actionColor,
            title: 'Backup Code',
            subtitle:
                'Used to log in if you lose access to your device.',
            trailing: TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      SfxService.tap();
                      _regenerateBackupCode();
                    },
              style: TextButton.styleFrom(
                foregroundColor: _actionColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: const Text(
                'Regenerate',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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
      backgroundColor: _bg,
      body: SafeArea(child: content),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(subtitle, style: AppText.caption),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 12, color: AppColors.accentGreen),
          SizedBox(width: 3),
          Text(
            'Verified',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnverifiedBadge extends StatelessWidget {
  const _UnverifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 12, color: AppColors.accentOrange),
          SizedBox(width: 3),
          Text(
            'Unverified',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textOrange,
            ),
          ),
        ],
      ),
    );
  }
}