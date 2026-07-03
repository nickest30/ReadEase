import 'package:flutter/material.dart';
import '../../models/class_group.dart';
import '../../models/student.dart';

class ClassLeaderboardScreen extends StatelessWidget {
  const ClassLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final classGroup = args['classGroup'] as ClassGroup;
    final students = List<Student>.from(args['students'] as List)
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

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
                  Expanded(
                    child: Text(
                      'Class Leaderboard — ${classGroup.className}',
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
              const SizedBox(height: 16),

              Expanded(
                child: students.isEmpty
                    ? const Center(
                        child: Text(
                          'No students enrolled yet.',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            color: Color(0xFF6B7878),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: students.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final student = students[index];
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFFE9DCBE)),
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
                                      const Color(0xFFE8A93B),
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
                                        student.displayName,
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
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