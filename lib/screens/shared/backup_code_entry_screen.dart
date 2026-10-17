import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';

import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/backup_code.dart';
import '../../widgets/app_form.dart';

/// Shown when a user can't receive the SMS OTP.
/// Verifies the backup code they saved at signup against a bcrypt hash.
///
/// Rate-limited: 5 failed attempts → 15-minute lockout, keyed by
/// `backup:{uid}` in the login_attempts table. Re-entering the password
/// does NOT reset this lockout — only a successful verification does.
class BackupCodeEntryScreen extends StatefulWidget {
  final String uid;                 // Firebase UID (for rate-limit keying)
  final String backupCodeHash;      // bcrypt hash from cloud
  final Color accentColor;
  final Color backgroundColor;

  /// Called with the newly-generated backup code after successful verification.
  final void Function(String newBackupCode) onVerified;

  /// Called when the user wants to go back to the OTP screen.
  final VoidCallback? onBackPressed;

  const BackupCodeEntryScreen({
    super.key,
    required this.uid,
    required this.backupCodeHash,
    required this.accentColor,
    required this.backgroundColor,
    required this.onVerified,
    this.onBackPressed,
  });

  @override
  State<BackupCodeEntryScreen> createState() => _BackupCodeEntryScreenState();
}

class _BackupCodeEntryScreenState extends State<BackupCodeEntryScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _isVerifying = false;
  bool _isLocked = false;
  Duration _lockRemaining = Duration.zero;
  Timer? _lockTimer;
  String? _errorMessage;

  String get _rateKey => 'backup:${widget.uid}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkInitialLock();
      if (mounted && !_isLocked) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    final remaining =
        await DatabaseService.instance.loginRateLimitRemaining(_rateKey);
    if (!mounted) return;
    if (remaining != null) {
      setState(() {
        _isLocked = true;
        _lockRemaining = remaining;
      });
      _startCountdown();
    }
  }

  void _startCountdown() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final remaining =
          await DatabaseService.instance.loginRateLimitRemaining(_rateKey);
      if (!mounted) return;
      if (remaining == null || remaining.inSeconds <= 0) {
        _lockTimer?.cancel();
        setState(() {
          _isLocked = false;
          _lockRemaining = Duration.zero;
        });
        _focusNode.requestFocus();
      } else {
        setState(() => _lockRemaining = remaining);
      }
    });
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _verify() async {
    if (_isLocked || _isVerifying) return;

    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    // Re-check lock (another device might have triggered it).
    final alreadyLocked =
        await DatabaseService.instance.isLoginRateLimited(_rateKey);
    if (!mounted) return;
    if (alreadyLocked) {
      setState(() => _isVerifying = false);
      await _checkInitialLock();
      return;
    }

    final isCorrect = BCrypt.checkpw(code, widget.backupCodeHash);

    if (!mounted) return;

    if (!isCorrect) {
      HapticFeedback.mediumImpact();

      // Record the failure
      await DatabaseService.instance.recordLoginAttempt(
        identifier: _rateKey,
        success: false,
      );

      if (!mounted) return;

      // Did this attempt trigger lockout?
      final remaining = await DatabaseService.instance
          .loginRateLimitRemaining(_rateKey);

      if (!mounted) return;

      if (remaining != null) {
        // Locked out
        setState(() {
          _isVerifying = false;
          _isLocked = true;
          _lockRemaining = remaining;
          _errorMessage = null;
        });
        _controller.clear();
        _startCountdown();
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Incorrect backup code';
        });
        _controller.clear();
        _focusNode.requestFocus();
      }
      return;
    }

    // ── Success ──
    HapticFeedback.heavyImpact();
    _lockTimer?.cancel();

    // Clear attempt history so future logins start fresh
    await DatabaseService.instance.clearLoginAttempts(_rateKey);

    if (!mounted) return;

    // Generate fresh code — the used one is now consumed
    final newCode = BackupCode.generate();
    widget.onVerified(newCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: widget.onBackPressed ??
                      () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  padding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: (_isLocked
                            ? AppColors.accentCoral
                            : widget.accentColor)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLocked ? Icons.lock_rounded : Icons.key_rounded,
                    size: 48,
                    color: _isLocked
                        ? AppColors.accentCoral
                        : widget.accentColor,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Text(
                _isLocked ? 'Too many attempts' : 'Enter your backup code',
                style: AppText.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _isLocked
                    ? 'Try again in ${_formatRemaining(_lockRemaining)}'
                    : 'Use the 6-digit code you saved at signup.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),

              TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_isLocked && !_isVerifying,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: buildInputDecoration(
                  hint: '••••••',
                  focusColor: widget.accentColor,
                ).copyWith(counterText: ''),
                onChanged: (value) {
                  if (value.length == 6 && !_isLocked) _verify();
                },
              ),

              const SizedBox(height: AppSpacing.md),

              SizedBox(
                height: 22,
                child: _errorMessage != null
                    ? Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(
                          color: AppColors.textCoral,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      (_isLocked || _isVerifying) ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _isLocked ? 'LOCKED' : 'VERIFY',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
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