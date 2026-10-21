import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_form.dart';

/// Full-screen OTP entry for phone verification.
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final Color accentColor;
  final Color backgroundColor;
  final bool isSignup;
  final VoidCallback onVerified;
  final VoidCallback? onNoPhoneFallback;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.accentColor,
    required this.backgroundColor,
    required this.isSignup,
    required this.onVerified,
    this.onNoPhoneFallback,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isVerifying = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _resendCooldown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _verifyCode() async {
    SfxService.tap();

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();

    bool ok = false;
    try {
      ok = await authProvider.confirmPhoneCode(code);
    } catch (e) {
      debugPrint('Phone code confirmation failed: $e');
    }

    if (!mounted) return;

    if (!ok) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Incorrect, expired, or connection lost. Try again.';
      });
      _codeController.clear();
      _focusNode.requestFocus();
      return;
    }

    HapticFeedback.heavyImpact();
    widget.onVerified();
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;
    SfxService.tap();

    setState(() {
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.startPhoneVerification(
        phoneNumber: widget.phoneNumber.replaceAll(' ', ''),
        onCodeSent: () {
          if (!mounted) return;
          _startResendCooldown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'New code sent',
                style: TextStyle(fontFamily: 'Nunito'),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onAutoVerified: () {
          if (!mounted) return;
          widget.onVerified();
        },
        onError: (msg) {
          if (!mounted) return;
          setState(() => _errorMessage = msg);
        },
      );
    } catch (e) {
      debugPrint('Phone verification restart failed: $e');
      if (!mounted) return;
      setState(() => _errorMessage = 'Connection error. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isSignup,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    if (!widget.isSignup)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () {
                            SfxService.tap();
                            Navigator.of(context).pop();
                          },
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
                          color: widget.accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sms_rounded,
                          size: 48,
                          color: widget.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Enter your code',
                      style: AppText.h1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'We sent a 6-digit code to\n${widget.phoneNumber}',
                      style: AppText.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextField(
                      controller: _codeController,
                      focusNode: _focusNode,
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
                        if (value.length == 6) {
                          _verifyCode();
                        }
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
                        onPressed: _isVerifying ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          foregroundColor: Colors.white,
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
                            : const Text(
                                'VERIFY',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed: _canResend ? _resendCode : null,
                        child: Text(
                          _canResend
                              ? 'Resend code'
                              : 'Resend in ${_resendCooldown}s',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: _canResend
                                ? widget.accentColor
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    if (!widget.isSignup && widget.onNoPhoneFallback != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            SfxService.tap();
                            widget.onNoPhoneFallback?.call();
                            Navigator.of(context).pop(false);
                          },
                          child: const Text(
                            'I don\'t have my phone',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}