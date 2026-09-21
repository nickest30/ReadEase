import 'package:flutter/material.dart';


class ColorBlindFilter extends StatelessWidget {
  final String mode;
  final Widget child;

  const ColorBlindFilter({
    super.key,
    required this.mode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == 'none') return child;

    final matrix = _matrixFor(mode);
    if (matrix == null) return child;

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
  }

  List<double>? _matrixFor(String mode) {
    switch (mode) {
      case 'protanopia':
        return const [
          0.567, 0.433, 0.000, 0, 0,
          0.558, 0.442, 0.000, 0, 0,
          0.000, 0.242, 0.758, 0, 0,
          0, 0, 0, 1, 0,
        ];

      case 'deuteranopia':
        return const [
          0.625, 0.375, 0.000, 0, 0,
          0.700, 0.300, 0.000, 0, 0,
          0.000, 0.300, 0.700, 0, 0,
          0, 0, 0, 1, 0,
        ];

      case 'tritanopia':
        return const [
          0.950, 0.050, 0.000, 0, 0,
          0.000, 0.433, 0.567, 0, 0,
          0.000, 0.475, 0.525, 0, 0,
          0, 0, 0, 1, 0,
        ];

      default:
        return null;
    }
  }
}