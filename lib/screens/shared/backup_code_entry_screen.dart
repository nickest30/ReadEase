import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';

import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/backup_code.dart';
import '../../widgets/app_form.dart';

class BackupCodeEntryScreen extends StatefulWidget {
  final String uid;
  final String backupCodeHash;
  final Color accentColor;
  final Color backgroundColor;
  final void Function(String newBackupCode) onVerified;
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

      await DatabaseService.instance.recordLoginAttempt(
        identifier: _rateKey,
        success: false,
      );

      if (!mounted) return;

      final remaining = await DatabaseService.instance
          .loginRateLimitRemaining(_rateKey);

      if (!mounted) return;

      if (remaining != null) {
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

    HapticFeedback.heavyImpact();
    _lockTimer?.cancel();

    await DatabaseService.instance.clearLoginAttempts(_rateKey);

    if (!mounted) return;

    final newCode = BackupCode.generate();
    widget.onVerified(newCode);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final iconSize = Responsive.imageSize(context, base: 96);
    final buttonHeight = Responsive.buttonHeight(context);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                SfxService.tap();
                if (widget.onBackPressed != null) {
                  widget.onBackPressed!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.textPrimary),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: (_isLocked
                        ? AppColors.accentCoral
                        : widget.accentColor)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isLocked ? Icons.lock_rounded : Icons.key_rounded,
                size: iconSize * 0.5,
                color: _isLocked
                    ? AppColors.accentCoral
                    : widget.accentColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _isLocked ? 'Too many attempts' : 'Enter your backup code',
              style: AppText.h1,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _isLocked
                  ? 'Try again in ${_formatRemaining(_lockRemaining)}'
                  : 'Use the 6-digit code you saved at signup.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
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
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        color: AppColors.textCoral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: (_isLocked || _isVerifying)
                  ? null
                  : () {
                      SfxService.tap();
                      _verify();
                    },
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
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isLocked ? 'LOCKED' : 'VERIFY',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
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
      backgroundColor: widget.backgroundColor,
      body: SafeArea(child: content),
    );
  }
}