import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Shared About dialog for all three roles (student, parent, teacher).
/// Shows app info, team credits, and the data-privacy note.
class AboutModal {
  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header: Yse salute + app name ──
                  Center(
                    child: Image.asset(
                      'assets/images/mascot/yse_salute.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 110,
                        height: 110,
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 72,
                          color: AppColors.accentTeal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Text(
                      'ReadEase',
                      style: AppText.display.copyWith(
                        fontSize: 28,
                        color: AppColors.accentTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Center(
                    child: Text(
                      'Read at your own ease.',
                      style: AppText.caption,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Description ──
                  const Text(
                    'A gamified reading aid application designed for '
                    'Filipino elementary learners in Grades 1–6 who '
                    'experience difficulty with reading. ReadEase combines '
                    'audio-visual lessons, leveled content, and interactive '
                    'games to build reading skills and confidence.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  _sectionLabel('Developed By'),
                  const SizedBox(height: AppSpacing.sm),
                  const _PersonRow(
                    name: 'Nikcol F. Estabaya',
                    role: 'Lead Full-Stack Developer',
                  ),
                  const _PersonRow(
                    name: 'Kevin V. Agapay',
                    role: 'Researcher',
                  ),
                  const _PersonRow(
                    name: 'Margarette B. Cipriano',
                    role: 'Researcher',
                  ),
                  const _PersonRow(
                    name: 'Chricielle Jhoebeth M. Gapay',
                    role: 'Researcher',
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  _sectionLabel('Project Guidance'),
                  const SizedBox(height: AppSpacing.sm),
                  const _PersonRow(
                    name: 'Leny Z. Laya',
                    role: 'Capstone Project Adviser',
                  ),
                  const _PersonRow(
                    name: 'Joselito G. Oyao',
                    role: 'Capstone Project Coordinator',
                  ),
                  const _PersonRow(
                    name: 'Mark Frederick V. Salonga',
                    role: 'Program Head',
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  _sectionLabel('Institution'),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'STI College Global City\n'
                    'Bachelor of Science in Information Technology',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: AppColors.accentTeal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.privacy_tip_rounded,
                          color: AppColors.accentTeal,
                          size: 20,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Complies with the Data Privacy Act of 2012 '
                            '(Republic Act 10173).',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTeal,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                      child: const Text(
                        'CLOSE',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String name;
  final String role;

  const _PersonRow({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 9, right: 8),
            decoration: const BoxDecoration(
              color: AppColors.accentTeal,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}