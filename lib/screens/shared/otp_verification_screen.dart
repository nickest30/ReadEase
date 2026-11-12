import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_form.dart';

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
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sms_rounded,
                size: iconSize * 0.5,
                color: widget.accentColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Enter your code',
              style: AppText.h1,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'We sent a 6-digit code to\n${widget.phoneNumber}',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
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
              onPressed: _isVerifying
                  ? null
                  : () {
                      SfxService.tap();
                      _verifyCode();
                    },
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
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'VERIFY',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: _canResend
                  ? () {
                      SfxService.tap();
                      _resendCode();
                    }
                  : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
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
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
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
            ),
          ],
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

    return PopScope(
      canPop: !widget.isSignup,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        body: SafeArea(child: content),
      ),
    );
  }
}