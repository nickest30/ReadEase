import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/quiz_result.dart';
import '../../services/database_service.dart';

class BadgeCollectionScreen extends StatefulWidget {
  const BadgeCollectionScreen({super.key});

  @override
  State<BadgeCollectionScreen> createState() =>
      _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState extends State<BadgeCollectionScreen> {
  List<QuizResult> _passing = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final student =
        ModalRoute.of(context)!.settings.arguments as Student;
    final results =
        await DatabaseService.instance.getResultsForStudent(student.id!);
    if (!mounted) return;
    setState(() {
      _passing = results.where((r) => r.isPassing).toList();
      _loading = false;
    });
  }

  String _badgeName(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Easy Reader';
      case 'medium':
        return 'Word Pro';
      case 'hard':
        return 'Hard Master';
      default:
        return difficulty;
    }
  }

  Color _badgeColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return const Color(0xFF2BAFA0);
      case 'medium':
        return const Color(0xFF8B5FBF);
      case 'hard':
        return const Color(0xFFFF6F61);
      default:
        return const Color(0xFF6B7878);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF2E3A3A)),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'My Badges',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E3A3A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Look at your brilliant collection!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _passing.isEmpty
                        ? const Center(
                            child: Text(
                              'No badges yet!\nComplete a quiz with 70% or higher\nto earn your first badge.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                color: Color(0xFF6B7878),
                              ),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1,
                            ),
                            itemCount: _passing.length,
                            itemBuilder: (context, index) {
                              final result = _passing[index];
                              final color =
                                  _badgeColor(result.difficulty);
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE9DCBE)),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.emoji_events_rounded,
                                        color: color,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _badgeName(result.difficulty),
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF2E3A3A),
                                      ),
                                    ),
                                    Text(
                                      'Grade ${result.gradeLevel}',
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 11,
                                        color: Color(0xFF6B7878),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}