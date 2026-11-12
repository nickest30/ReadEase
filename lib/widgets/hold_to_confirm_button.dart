import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx_service.dart';
import '../utils/app_theme.dart';

class HoldToConfirmButton extends StatefulWidget {
  final String label;
  final String holdingLabel;
  final String confirmedLabel;
  final Duration holdDuration;
  final bool enabled;
  final VoidCallback onConfirmed;
  final Color? color;
  final IconData? icon;

  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdingLabel = 'Keep holding…',
    this.confirmedLabel = 'Confirmed!',
    this.holdDuration = const Duration(seconds: 5),
    this.enabled = true,
    this.color,
    this.icon,
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _holding = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        _onHoldComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled || _completed || _holding) return;
    SfxService.tap();
    HapticFeedback.selectionClick();
    setState(() => _holding = true);
    _controller.forward(from: 0);
  }

  void _release() {
    if (!_holding || _completed) return;
    if (_controller.value < 1.0) {
      HapticFeedback.lightImpact();
      _controller.reverse().then((_) {
        if (mounted) setState(() => _holding = false);
      });
    } else {
      setState(() => _holding = false);
    }
  }

  void _onHoldComplete() {
    if (_completed) return;
    SfxService.correct();
    HapticFeedback.heavyImpact();
    setState(() {
      _completed = true;
      _holding = false;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) widget.onConfirmed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = Responsive.buttonHeight(context) + 8;
    final accent = widget.color ?? AppColors.accentTeal;
    final disabled = !widget.enabled;

    Color bgColor;
    Color fgColor;
    Color fillColor;
    String text;
    IconData iconData;

    if (_completed) {
      bgColor = const Color(0xFF4CAF50);
      fgColor = Colors.white;
      fillColor = const Color(0xFF4CAF50);
      text = widget.confirmedLabel;
      iconData = Icons.check_circle_rounded;
    } else if (disabled) {
      bgColor = AppColors.border.withValues(alpha: 0.3);
      fgColor = AppColors.textMuted;
      fillColor = Colors.transparent;
      text = widget.label;
      iconData = widget.icon ?? Icons.touch_app_rounded;
    } else {
      bgColor = AppColors.border.withValues(alpha: 0.35);
      fgColor = AppColors.textPrimary;
      fillColor = accent.withValues(alpha: 0.45);
      text = _holding ? widget.holdingLabel : widget.label;
      iconData = widget.icon ?? Icons.touch_app_rounded;
    }

    return Listener(
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: disabled
              ? Border.all(color: AppColors.border, width: 1.5)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (!disabled && !_completed)
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) {
                    return FractionallySizedBox(
                      widthFactor: _controller.value.clamp(0.0, 1.0),
                      child: Container(color: fillColor),
                    );
                  },
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconData, size: 20, color: fgColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          text,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: fgColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}