import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Student> _students = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final students = await DatabaseService.instance.getAllStudents();
    students.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    if (!mounted) return;
    setState(() {
      _students = students;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStudent =
        ModalRoute.of(context)!.settings.arguments as Student;

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
                    'Leaderboard',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E3A3A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabs placeholder — Class and Global wired up
              // later with Firebase
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9DCBE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'Local',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF2BAFA0),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: 0.5,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: const Text(
                            'Class',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF6B7878),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: 0.5,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: const Text(
                            'Global',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF6B7878),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _students.isEmpty
                        ? const Center(
                            child: Text(
                              'No students yet.',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                color: Color(0xFF6B7878),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _students.length,
                            separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              final isCurrentUser =
                                  student.id == currentStudent.id;
                              final rank = index + 1;

                              Color rankColor = const Color(0xFF6B7878);
                              if (rank == 1) {
                                rankColor = const Color(0xFFE8A93B);
                              } else if (rank == 2) {
                                rankColor = const Color(0xFF9E9E9E);
                              } else if (rank == 3) {
                                rankColor = const Color(0xFFCD7F32);
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? const Color(0xFFDCF1ED)
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isCurrentUser
                                        ? const Color(0xFF2BAFA0)
                                        : const Color(0xFFE9DCBE),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '#$rank',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: rankColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          const Color(0xFF2BAFA0),
                                      child: Text(
                                        student.displayName[0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.displayName +
                                                (isCurrentUser
                                                    ? ' (you)'
                                                    : ''),
                                            style: const TextStyle(
                                              fontFamily: 'Nunito',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF2E3A3A),
                                            ),
                                          ),
                                          Text(
                                            'Grade ${student.gradeLevel}',
                                            style: const TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 11,
                                              color: Color(0xFF6B7878),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${student.totalPoints} pts',
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFFE8A93B),
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