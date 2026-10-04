import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Distinct color per dot position — teal, green, yellow, coral.
/// Matches ReadEase accent palette.
const kPinDotColors = [
  AppColors.accentTeal,
  AppColors.accentGreen,
  AppColors.accentYellow,
  AppColors.accentCoral,
];

/// Whole-PIN feedback colors.
const kPinErrorColor = AppColors.accentCoral;
const kPinSuccessColor = AppColors.accentGreen;

enum PinDotState { idle, error, success }

/// Row of 4 PIN dots. Fills with per-position colors as the user types.
/// Shakes horizontally and flashes coral on [PinDotState.error].
/// Pulses green on [PinDotState.success].
class PinDots extends StatefulWidget {
  final int filledCount;
  final PinDotState state;

  const PinDots({
    super.key,
    required this.filledCount,
    this.state = PinDotState.idle,
  });

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didUpdateWidget(covariant PinDots old) {
    super.didUpdateWidget(old);
    if (widget.state == PinDotState.error &&
        old.state != PinDotState.error) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = t == 0 ? 0.0 : (1 - t) * 10 * (t * 20 % 2 < 1 ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final filled = i < widget.filledCount;
          final color = !filled
              ? Colors.transparent
              : widget.state == PinDotState.error
                  ? kPinErrorColor
                  : widget.state == PinDotState.success
                      ? kPinSuccessColor
                      : kPinDotColors[i % kPinDotColors.length];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: filled ? color : AppColors.border,
                  width: 2,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}