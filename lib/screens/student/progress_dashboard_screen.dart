import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/quiz_result.dart';
import '../../services/database_service.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  List<QuizResult> _results = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final student =
        ModalRoute.of(context)!.settings.arguments as Student;
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

  int get _totalPoints =>
      _results.fold(0, (sum, r) => sum + r.pointsEarned);

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'My Progress',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E3A3A),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'No progress yet.\nComplete a quiz to see your stats!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              color: Color(0xFF6B7878),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              // Summary row
                              Row(
                                children: [
                                  _StatCard(
                                    label: 'Levels Done',
                                    value: '$_completedLevels',
                                    color: const Color(0xFF2BAFA0),
                                  ),
                                  const SizedBox(width: 10),
                                  _StatCard(
                                    label: 'Total Points',
                                    value: '$_totalPoints',
                                    color: const Color(0xFFE8A93B),
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

                              // Overall completion bar
                              const Text(
                                'OVERALL COMPLETION',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .05,
                                  color: Color(0xFF6B7878),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _completedLevels / 18,
                                  minHeight: 12,
                                  backgroundColor: const Color(0xFFE9DCBE),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2BAFA0),
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

                              // Quiz scores list
                              const Text(
                                'QUIZ SCORES',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .05,
                                  color: Color(0xFF6B7878),
                                ),
                              ),
                              const SizedBox(height: 8),
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
                                        color: const Color(0xFFE9DCBE)),
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
                                            color: Color(0xFF2E3A3A),
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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