import 'dart:math';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
// Question type breakdown — horizontal bars
// ═══════════════════════════════════════════════════════════════

class QuestionTypeBreakdown extends StatelessWidget {
  /// Map from question type to { total, correct }.
  final Map<String, Map<String, int>> stats;

  const QuestionTypeBreakdown({super.key, required this.stats});

  static const _order = ['literal', 'inferential', 'critical'];
  static const _labels = {
    'literal': 'Literal',
    'inferential': 'Inferential',
    'critical': 'Critical',
  };
  static const _colors = {
    'literal': AppColors.accentTeal,
    'inferential': AppColors.accentOrange,
    'critical': AppColors.accentCoral,
  };

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter to types that have data, keep order
    final visibleTypes =
        _order.where((t) => (stats[t]?['total'] ?? 0) > 0).toList();

    if (visibleTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.psychology_rounded,
              size: 16,
              color: AppColors.accentPurple,
            ),
            const SizedBox(width: 6),
            const Text(
              'READING SKILLS',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.textPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: visibleTypes.map((type) {
              final total = stats[type]!['total'] ?? 0;
              final correct = stats[type]!['correct'] ?? 0;
              final accuracy = total == 0 ? 0.0 : correct / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TypeRow(
                  label: _labels[type] ?? type,
                  correct: correct,
                  total: total,
                  accuracy: accuracy,
                  color: _colors[type] ?? AppColors.accentTeal,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String label;
  final int correct;
  final int total;
  final double accuracy;
  final Color color;

  const _TypeRow({
    required this.label,
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$correct / $total',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(accuracy * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: accuracy,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Mastery donut — 3-way split
// ═══════════════════════════════════════════════════════════════

class MasteryDonut extends StatelessWidget {
  final int mastered;
  final int struggling;
  final int learning;

  const MasteryDonut({
    super.key,
    required this.mastered,
    required this.struggling,
    required this.learning,
  });

  int get _total => mastered + struggling + learning;

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.donut_large_rounded,
              size: 16,
              color: AppColors.accentPurple,
            ),
            const SizedBox(width: 6),
            const Text(
              'WORD MASTERY',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.textPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _DonutPainter(
                    mastered: mastered,
                    struggling: struggling,
                    learning: learning,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_total',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'words',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Legend(
                      color: AppColors.accentGreen,
                      label: 'Mastered',
                      value: mastered,
                    ),
                    const SizedBox(height: 6),
                    _Legend(
                      color: AppColors.accentOrange,
                      label: 'Learning',
                      value: learning,
                    ),
                    const SizedBox(height: 6),
                    _Legend(
                      color: AppColors.accentCoral,
                      label: 'Struggling',
                      value: struggling,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int mastered;
  final int struggling;
  final int learning;

  _DonutPainter({
    required this.mastered,
    required this.struggling,
    required this.learning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = mastered + struggling + learning;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Start from top (-π/2)
    var startAngle = -pi / 2;

    // Mastered (green)
    if (mastered > 0) {
      final sweep = (mastered / total) * 2 * pi;
      paint.color = AppColors.accentGreen;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }

    // Learning (orange)
    if (learning > 0) {
      final sweep = (learning / total) * 2 * pi;
      paint.color = AppColors.accentOrange;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }

    // Struggling (coral)
    if (struggling > 0) {
      final sweep = (struggling / total) * 2 * pi;
      paint.color = AppColors.accentCoral;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.mastered != mastered ||
        old.struggling != struggling ||
        old.learning != learning;
  }
}