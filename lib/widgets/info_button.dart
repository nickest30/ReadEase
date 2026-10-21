import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class InfoButton extends StatelessWidget {
  final String title;
  final String description;
  final List<String> steps;

  const InfoButton({
    super.key,
    required this.title,
    required this.description,
    required this.steps,
  });

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.accentTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            ...steps.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentTeal)),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Got it!', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showInfo(context),
      icon: const Icon(Icons.help_outline_rounded, color: AppColors.accentTeal),
      tooltip: 'How to play',
    );
  }
}