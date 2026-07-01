import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class DifficultySelectionScreen extends StatefulWidget {
  const DifficultySelectionScreen({super.key});

  @override
  State<DifficultySelectionScreen> createState() => _DifficultySelectionScreenState();
}

class _DifficultySelectionScreenState extends State<DifficultySelectionScreen> {
  bool _loading = true;
  bool _mediumUnlocked = false;
  bool _hardUnlocked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUnlocks();
  }

  Future<void> _checkUnlocks() async {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final student = args['student'] as Student;
    final gradeLevel = args['gradeLevel'] as int;

    final passedEasy = await DatabaseService.instance
        .hasPassedDifficulty(student.id!, gradeLevel, 'easy');
    final passedMedium = await DatabaseService.instance
        .hasPassedDifficulty(student.id!, gradeLevel, 'medium');

    if (!mounted) return;
    setState(() {
      _mediumUnlocked = passedEasy;
      _hardUnlocked = passedMedium;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final student = args['student'] as Student;
    final gradeLevel = args['gradeLevel'] as int;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3A3A)),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              const Text(
                'Difficulty Selection',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),
              const Text(
                'Choose difficulty',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _DifficultyCard(
                  emoji: '😎',
                  label: 'Easy',
                  sublabel: 'Unlocked',
                  unlocked: true,
                  onTap: () => _goToLesson(context, student, gradeLevel, 'easy'),
                ),
                const SizedBox(height: 14),
                _DifficultyCard(
                  emoji: '😐',
                  label: 'Medium',
                  sublabel: _mediumUnlocked ? 'Unlocked' : 'Complete Easy first',
                  unlocked: _mediumUnlocked,
                  onTap: _mediumUnlocked
                      ? () => _goToLesson(context, student, gradeLevel, 'medium')
                      : null,
                ),
                const SizedBox(height: 14),
                _DifficultyCard(
                  emoji: '😈',
                  label: 'Hard',
                  sublabel: _hardUnlocked ? 'Unlocked' : 'Complete Medium first',
                  unlocked: _hardUnlocked,
                  onTap: _hardUnlocked
                      ? () => _goToLesson(context, student, gradeLevel, 'hard')
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _goToLesson(BuildContext context, Student student, int gradeLevel, String difficulty) {
    Navigator.of(context).pushNamed(
      '/lesson',
      arguments: {
        'student': student,
        'gradeLevel': gradeLevel,
        'difficulty': difficulty,
      },
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final bool unlocked;
  final VoidCallback? onTap;

  const _DifficultyCard({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9DCBE)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF2E3A3A),
                      ),
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Color(0xFF6B7878),
                      ),
                    ),
                  ],
                ),
              ),
              if (!unlocked) const Icon(Icons.lock, color: Color(0xFF6B7878)),
            ],
          ),
        ),
      ),
    );
  }
}