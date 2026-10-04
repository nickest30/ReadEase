import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Circular numeric keypad used on all PIN screens.
/// Backspace is rendered with [Icons.backspace_rounded] so it stays
/// optically centered inside the circle.
class NumberPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  const NumberPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const layout = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1.0 : 0.5,
      child: Column(
        children: layout.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 72, height: 64);
              return Padding(
                padding: const EdgeInsets.all(6),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: enabled
                        ? () => key == '⌫' ? onBackspace() : onDigit(key)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor: AppColors.surface,
                      disabledForegroundColor: AppColors.textMuted,
                      elevation: 1,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: key == '⌫'
                        ? const Icon(
                            Icons.backspace_rounded,
                            size: 22,
                            color: AppColors.textPrimary,
                          )
                        : Text(
                            key,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}