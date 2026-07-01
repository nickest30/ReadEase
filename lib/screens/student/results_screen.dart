import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/quiz_result.dart';
import '../../services/database_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _saved = false;
  bool _isPassing = false;
  int _pointsEarned = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_saved) {
      _saved = true;
      _saveResult();
    }
  }

  Future<void> _saveResult() async {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final student = args['student'] as Student;
    final gradeLevel = args['gradeLevel'] as int;
    final difficulty = args['difficulty'] as String;
    final score = args['score'] as int;
    final totalQuestions = args['totalQuestions'] as int;

    final pointsEarned = score * 5; // 5 points per correct answer

    final result = QuizResult(
      studentId: student.id!,
      gradeLevel: gradeLevel,
      difficulty: difficulty,
      score: score,
      totalQuestions: totalQuestions,
      pointsEarned: pointsEarned,
      completedAt: DateTime.now().toIso8601String(),
    );

    await DatabaseService.instance.insertQuizResult(result);
    await DatabaseService.instance.addPoints(student.id!, pointsEarned);

    if (!mounted) return;
    setState(() {
      _isPassing = result.isPassing;
      _pointsEarned = pointsEarned;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final student = args['student'] as Student;
    final gradeLevel = args['gradeLevel'] as int;
    final score = args['score'] as int;
    final totalQuestions = args['totalQuestions'] as int;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Quiz Complete!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$score / $totalQuestions',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8B5FBF),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starsEarned = ((score / totalQuestions) * 5).round();
                  return Icon(
                    index < starsEarned ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFE8A93B),
                    size: 28,
                  );
                }),
              ),

              const SizedBox(height: 32),

              if (_isPassing)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8A93B)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFE8A93B), size: 44),
                      const SizedBox(height: 8),
                      const Text(
                        'Badge Earned!',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF2E3A3A),
                        ),
                      ),
                      Text(
                        '+$_pointsEarned points',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          color: Color(0xFF6B7878),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE9DCBE)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Almost there!',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF2E3A3A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Score 70% or higher to earn a badge\nand unlock the next level.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Color(0xFF6B7878),
                        ),
                      ),
                      Text(
                        '+$_pointsEarned points',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          color: Color(0xFF6B7878),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed(
                          '/difficulty-selection',
                          arguments: {
                            'student': student,
                            'gradeLevel': gradeLevel,
                          },
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: const Color(0xFFE8A93B),
                        side: const BorderSide(color: Color(0xFFE8A93B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/student-home',
                          (route) => false,
                          arguments: student,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2BAFA0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Back to Levels',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}