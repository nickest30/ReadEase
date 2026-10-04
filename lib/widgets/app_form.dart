import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Shared text-field decoration used across all ReadEase forms.
/// [focusColor] defaults to teal (student role); pass purple for parent/teacher.
InputDecoration buildInputDecoration({
  required String hint,
  Color focusColor = AppColors.accentTeal,
}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      borderSide: BorderSide(color: focusColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      borderSide: const BorderSide(color: AppColors.accentCoral, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      borderSide: const BorderSide(color: AppColors.accentCoral, width: 2),
    ),
  );
}

/// Field label used above form inputs.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Password input with show/hide toggle.
/// Tap target is 48x48 per NFR-11.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final bool enabled;
  final Color focusColor;

  const PasswordField({
    super.key,
    required this.controller,
    required this.hintText,
    this.validator,
    this.textInputAction,
    this.enabled = true,
    this.focusColor = AppColors.accentTeal,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  void _toggle() => setState(() => _obscured = !_obscured);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      enabled: widget.enabled,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      decoration: buildInputDecoration(
        hint: widget.hintText,
        focusColor: widget.focusColor,
      ).copyWith(
        suffixIcon: IconButton(
          onPressed: widget.enabled ? _toggle : null,
          tooltip: _obscured ? 'Show password' : 'Hide password',
          splashRadius: 24,
          icon: Icon(
            _obscured
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: AppColors.textMuted,
            size: 22,
          ),
        ),
      ),
    );
  }
}