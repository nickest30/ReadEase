import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/backup_code.dart';
import '../shared/backup_code_screen.dart';
import '../shared/otp_verification_screen.dart';

/// Shared account security settings for parent + teacher.
/// Lets them view email, change phone, and regenerate backup codes.
class AccountSecurityScreen extends StatefulWidget {
  final String role; // 'parent' | 'teacher'

  const AccountSecurityScreen({super.key, required this.role});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool _busy = false;
  String? _errorMessage;

  bool get _isParent => widget.role == 'parent';

  Color get _accent =>
      _isParent ? AppColors.accentPurple : AppColors.accentYellow;

  Color get _bg =>
      _isParent ? AppColors.parentBg : AppColors.teacherBg;

  // ── Normalize PH phone to E.164 ──
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

  // ── Masked display: "+63 *** 6789" ──
  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    final ccEnd = phone.startsWith('+63')
        ? 3
        : (phone.startsWith('+') ? 2 : 0);
    final cc = phone.substring(0, ccEnd);
    final last4 = phone.substring(phone.length - 4);
    return '$cc *** $last4';
  }

  // ────────────────────────────────────────────────────────────
  // CHANGE PHONE
  // ────────────────────────────────────────────────────────────

  Future<void> _changePhone() async {
    // Capture providers BEFORE any await
    final authProvider = context.read<AuthProvider>();
    final uid = _isParent
        ? context.read<ParentProvider>().currentParent?.firebaseUid
        : context.read<TeacherProvider>().currentTeacher?.firebaseUid;

    final controller = TextEditingController();

    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Change Phone Number',
          style: AppText.h2.copyWith(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the new phone number. We\'ll send a code to '
              'confirm it before updating your account.',
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '912 345 6789',
                filled: true,
                fillColor: AppColors.studentBg,
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
                  borderSide: BorderSide(color: _accent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor:
                  _isParent ? Colors.white : AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
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
          'Invalid number. Use format like 9123456789 or +639123456789.');
      return;
    }

    await _runPhoneLinkFlow(
      normalizedPhone: normalized,
      authProvider: authProvider,
      uid: uid,
    );
  }

  Future<void> _runPhoneLinkFlow({
    required String normalizedPhone,
    required AuthProvider authProvider,
    required String? uid,
  }) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    // Trigger OTP to the new number
    final completer = Completer<bool>();
    bool codeSent = false;

    await authProvider.startPhoneVerification(
      phoneNumber: normalizedPhone,
      onCodeSent: () {
        codeSent = true;
        if (!completer.isCompleted) completer.complete(true);
      },
      onAutoVerified: () {
        if (!completer.isCompleted) completer.complete(true);
      },
      onError: (msg) {
        debugPrint('📱 send failed: $msg');
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    final sent = await completer.future;
    if (!sent || !mounted || !codeSent) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMessage = 'Could not send code. Try again.';
        });
      }
      return;
    }

    // Show OTP screen
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: normalizedPhone,
          accentColor: _accent,
          backgroundColor: _bg,
          isSignup: false,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (verified != true || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    // ── Persist change ──
    if (uid == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMessage = 'Session expired. Please log in again.';
        });
      }
      return;
    }

    // Cloud
    await FirestoreService.instance.updatePhoneNumber(
      uid: uid,
      role: widget.role,
      phoneNumber: normalizedPhone,
      verified: true,
    );

    // Local — capture providers again after the await
    if (!mounted) return;
    if (_isParent) {
      final parent = context.read<ParentProvider>().currentParent;
      if (parent?.id != null) {
        await DatabaseService.instance.updateParentPhone(
          parent!.id!,
          normalizedPhone,
          true,
        );
        final updated =
            await DatabaseService.instance.getParentById(parent.id!);
        if (updated != null && mounted) {
          context.read<ParentProvider>().setParent(updated);
        }
      }
    } else {
      final teacher = context.read<TeacherProvider>().currentTeacher;
      if (teacher?.id != null) {
        await DatabaseService.instance.updateTeacherPhone(
          teacher!.id!,
          normalizedPhone,
          true,
        );
        final updated =
            await DatabaseService.instance.getTeacherById(teacher.id!);
        if (updated != null && mounted) {
          context.read<TeacherProvider>().setTeacher(updated);
        }
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Phone number updated',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // REGENERATE BACKUP CODE
  // ────────────────────────────────────────────────────────────

  Future<void> _regenerateBackupCode() async {
    // Capture everything BEFORE any await
    final authProvider = context.read<AuthProvider>();
    final phone = _isParent
        ? context.read<ParentProvider>().currentParent?.phoneNumber
        : context.read<TeacherProvider>().currentTeacher?.phoneNumber;
    final uid = _isParent
        ? context.read<ParentProvider>().currentParent?.firebaseUid
        : context.read<TeacherProvider>().currentTeacher?.firebaseUid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Regenerate Backup Code?',
          style: AppText.h2.copyWith(fontSize: 18),
        ),
        content: const Text(
          'Your current backup code will stop working. '
          'We\'ll verify your phone number first.',
          style: AppText.caption,
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
              backgroundColor: _accent,
              foregroundColor:
                  _isParent ? Colors.white : AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Continue',
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

    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a phone number first.',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Verify via OTP first
    final completer = Completer<bool>();
    bool codeSent = false;

    await authProvider.startPhoneVerification(
      phoneNumber: phone,
      onCodeSent: () {
        codeSent = true;
        if (!completer.isCompleted) completer.complete(true);
      },
      onAutoVerified: () {
        if (!completer.isCompleted) completer.complete(true);
      },
      onError: (msg) {
        debugPrint('📱 send failed: $msg');
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    final sent = await completer.future;
    if (!sent || !mounted || !codeSent) return;

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: phone,
          accentColor: _accent,
          backgroundColor: _bg,
          isSignup: false,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (verified != true || !mounted) return;

    // Generate new backup code
    final newCode = BackupCode.generate();
    final newHash = BCrypt.hashpw(newCode, BCrypt.gensalt());

    if (uid == null) return;

    await FirestoreService.instance
        .rotateBackupCode(uid, widget.role, newHash);

    // Update local DB — capture provider again after await
    if (!mounted) return;
    if (_isParent) {
      final parent = context.read<ParentProvider>().currentParent;
      if (parent?.id != null) {
        await DatabaseService.instance
            .updateParentBackupCodeHash(parent!.id!, newHash);
      }
    } else {
      final teacher = context.read<TeacherProvider>().currentTeacher;
      if (teacher?.id != null) {
        await DatabaseService.instance
            .updateTeacherBackupCodeHash(teacher!.id!, newHash);
      }
    }

    if (!mounted) return;

    await BackupCodeDialog.show(
      context,
      code: newCode,
      accentColor: _accent,
    );
  }

  // ────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────

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

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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

              // ── EMAIL ──
              _SectionCard(
                icon: Icons.alternate_email_rounded,
                iconColor: _accent,
                title: 'Email',
                subtitle: email,
                trailing: emailVerified
                    ? const _VerifiedBadge()
                    : const _UnverifiedBadge(),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── PHONE ──
              _SectionCard(
                icon: Icons.phone_rounded,
                iconColor: _accent,
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
                      onPressed: _busy ? null : _changePhone,
                      style: TextButton.styleFrom(
                        foregroundColor: _accent,
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

              // ── BACKUP CODE ──
              _SectionCard(
                icon: Icons.key_rounded,
                iconColor: _accent,
                title: 'Backup Code',
                subtitle:
                    'Used to log in if you lose access to your phone.',
                trailing: TextButton(
                  onPressed: _busy ? null : _regenerateBackupCode,
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
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
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Section card
// ────────────────────────────────────────────────────────────

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
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.caption,
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