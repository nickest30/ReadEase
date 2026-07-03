import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/quiz_result.dart';
import '../../services/database_service.dart';

class TeacherStudentProgressScreen extends StatefulWidget {
  const TeacherStudentProgressScreen({super.key});

  @override
  State<TeacherStudentProgressScreen> createState() =>
      _TeacherStudentProgressScreenState();
}

class _TeacherStudentProgressScreenState
    extends State<TeacherStudentProgressScreen> {
  List<QuizResult> _results = [];
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadResults();
    }
  }

  Future<void> _loadResults() async {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final student = args['student'] as Student;
    final results =
        await DatabaseService.instance.getResultsForStudent(student.id!);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  double get _overallAccuracy {
    if (_results.isEmpty) return 0;
    final total = _results.fold(0, (sum, r) => sum + r.totalQuestions);
    final correct = _results.fold(0, (sum, r) => sum + r.score);
    return total == 0 ? 0 : correct / total;
  }

  int get _completedLevels =>
      _results.where((r) => r.isPassing).length;

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final student = args['student'] as Student;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF2E3A3A)),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      student.displayName,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E3A3A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _StatCard(
                                label: 'Levels Done',
                                value: '$_completedLevels',
                                color: const Color(0xFFE8A93B),
                              ),
                              const SizedBox(width: 10),
                              _StatCard(
                                label: 'Points',
                                value: '${student.totalPoints}',
                                color: const Color(0xFF2BAFA0),
                              ),
                              const SizedBox(width: 10),
                              _StatCard(
                                label: 'Accuracy',
                                value:
                                    '${(_overallAccuracy * 100).toStringAsFixed(0)}%',
                                color: const Color(0xFF8B5FBF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _completedLevels / 18,
                              minHeight: 12,
                              backgroundColor:
                                  const Color(0xFFE9DCBE),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                Color(0xFFE8A93B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_completedLevels / 18 levels passed',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              color: Color(0xFF6B7878),
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_results.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'No quiz results yet.',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Color(0xFF6B7878),
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._results.map((result) {
                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          const Color(0xFFE9DCBE)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Grade ${result.gradeLevel} — ${_capitalize(result.difficulty)}',
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${result.score}/${result.totalQuestions}',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: result.isPassing
                                            ? const Color(0xFF2BAFA0)
                                            : const Color(0xFFFF6F61),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      result.isPassing
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 16,
                                      color: result.isPassing
                                          ? const Color(0xFF2BAFA0)
                                          : const Color(0xFFFF6F61),
                                    ),
                                  ],
                                ),
                              );
                            }),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9DCBE)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                color: Color(0xFF6B7878),
              ),
            ),
          ],
        ),
      ),
    );
  }
}