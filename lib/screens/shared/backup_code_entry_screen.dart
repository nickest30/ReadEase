import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';

import '../../utils/app_theme.dart';
import '../../utils/backup_code.dart';
import '../../widgets/app_form.dart';

/// Shown when a user can't receive the SMS OTP.
/// Verifies the backup code they saved at signup against a bcrypt hash.
///
/// On success: generates a fresh backup code, returns it via [onNewBackupCode].
/// The caller is responsible for saving + showing it.
class BackupCodeEntryScreen extends StatefulWidget {
  final String backupCodeHash;      // bcrypt hash from cloud
  final Color accentColor;
  final Color backgroundColor;

  /// Called with the newly-generated backup code after successful verification.
  final void Function(String newBackupCode) onVerified;

  /// Called when the user wants to go back to the OTP screen.
  final VoidCallback? onBackPressed;

  const BackupCodeEntryScreen({
    super.key,
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final isCorrect = BCrypt.checkpw(code, widget.backupCodeHash);

    if (!mounted) return;

    if (!isCorrect) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Incorrect backup code';
      });
      _controller.clear();
      _focusNode.requestFocus();
      return;
    }

    // Success — generate a fresh code to replace the used one
    HapticFeedback.heavyImpact();
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
                    color: widget.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.key_rounded,
                    size: 48,
                    color: widget.accentColor,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              const Text(
                'Enter your backup code',
                style: AppText.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Use the 6-digit code you saved at signup.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),

              TextField(
                controller: _controller,
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
                  if (value.length == 6) _verify();
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
                  onPressed: _isVerifying ? null : _verify,
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

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}