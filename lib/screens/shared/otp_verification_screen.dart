import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_form.dart';

/// Full-screen OTP entry for phone verification.
///
/// Two usage modes:
///   - Signup: link a new phone to a freshly-created account
///   - Login:  second-factor for an account with phoneVerified == true
///
/// On success, calls [onVerified] so the caller decides what happens next
/// (navigate to dashboard, show backup code, etc.).
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;     // display only, e.g. "+63 912 345 6789"
  final Color accentColor;      // role-based
  final Color backgroundColor;  // role-based
  final bool isSignup;
  final VoidCallback onVerified;
  final VoidCallback? onNoPhoneFallback; // only for login mode

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
    // Auto-focus the input
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
    final ok = await authProvider.confirmPhoneCode(code);

    if (!mounted) return;

    if (!ok) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Incorrect or expired code. Try again.';
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
    setState(() {
      _errorMessage = null;
    });

    // Re-trigger the phone verification flow.
    // AuthService holds the pending verification id, so this restarts it.
    final authProvider = context.read<AuthProvider>();
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
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent accidental back-navigation during signup OTP
      canPop: !widget.isSignup,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        body: SafeArea(
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                      padding: EdgeInsets.zero,
                    ),
                  ),

                const SizedBox(height: AppSpacing.lg),

                // Icon
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

                // Code input
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
                  ).copyWith(
                    counterText: '',
                  ),
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

                // Resend
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

                // Fallback for login mode only
                if (!widget.isSignup && widget.onNoPhoneFallback != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton(
                      onPressed: () {
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
    );
  }
}