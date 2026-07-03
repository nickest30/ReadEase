import 'package:flutter/material.dart';
import '../../models/class_group.dart';
import '../../models/student.dart';
import '../../models/quiz_result.dart';
import '../../services/database_service.dart';

class ClassAnalyticsScreen extends StatefulWidget {
  const ClassAnalyticsScreen({super.key});

  @override
  State<ClassAnalyticsScreen> createState() =>
      _ClassAnalyticsScreenState();
}

class _ClassAnalyticsScreenState extends State<ClassAnalyticsScreen> {
  List<QuizResult> _allResults = [];
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final students = args['students'] as List<Student>;

    final List<QuizResult> allResults = [];
    for (final student in students) {
      final results = await DatabaseService.instance
          .getResultsForStudent(student.id!);
      allResults.addAll(results);
    }

    if (!mounted) return;
    setState(() {
      _allResults = allResults;
      _loading = false;
    });
  }

  double get _avgScore {
    if (_allResults.isEmpty) return 0;
    final total = _allResults.fold(
        0.0, (sum, r) => sum + (r.score / r.totalQuestions));
    return total / _allResults.length;
  }

  int get _totalPassing =>
      _allResults.where((r) => r.isPassing).length;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final classGroup = args['classGroup'] as ClassGroup;
    final students = args['students'] as List<Student>;

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
                      'Class Analytics — ${classGroup.className}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
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
                                label: 'Students',
                                value: '${students.length}',
                                color: const Color(0xFFE8A93B),
                              ),
                              const SizedBox(width: 10),
                              _StatCard(
                                label: 'Avg Score',
                                value:
                                    '${(_avgScore * 100).toStringAsFixed(0)}%',
                                color: const Color(0xFF2BAFA0),
                              ),
                              const SizedBox(width: 10),
                              _StatCard(
                                label: 'Passing',
                                value: '$_totalPassing',
                                color: const Color(0xFF8B5FBF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_allResults.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'No quiz results in this class yet.',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Color(0xFF6B7878),
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            const Text(
                              'PER STUDENT SUMMARY',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .05,
                                color: Color(0xFF6B7878),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...students.map((student) {
                              final studentResults = _allResults
                                  .where((r) =>
                                      r.studentId == student.id)
                                  .toList();
                              final passingCount = studentResults
                                  .where((r) => r.isPassing)
                                  .length;
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
                                        student.displayName,
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$passingCount passed · ${student.totalPoints} pts',
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12,
                                        color: Color(0xFF6B7878),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
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