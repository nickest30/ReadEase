import 'package:flutter/material.dart';
import '../../models/teacher.dart';
import '../../models/class_group.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class ClassOverviewScreen extends StatefulWidget {
  const ClassOverviewScreen({super.key});

  @override
  State<ClassOverviewScreen> createState() =>
      _ClassOverviewScreenState();
}

class _ClassOverviewScreenState extends State<ClassOverviewScreen> {
  List<Student> _students = [];
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final classGroup = args['classGroup'] as ClassGroup;
    final students = await DatabaseService.instance
        .getStudentsInClass(classGroup.id!);
    if (!mounted) return;
    setState(() {
      _students = students;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final teacher = args['teacher'] as Teacher;
    final classGroup = args['classGroup'] as ClassGroup;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classGroup.className,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E3A3A),
                          ),
                        ),
                        Text(
                          'Join Code: ${classGroup.joinCode}',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE8A93B),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Analytics',
                      icon: Icons.bar_chart_rounded,
                      onTap: () => Navigator.of(context).pushNamed(
                        '/class-analytics',
                        arguments: {
                          'teacher': teacher,
                          'classGroup': classGroup,
                          'students': _students,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'Leaderboard',
                      icon: Icons.leaderboard_rounded,
                      onTap: () => Navigator.of(context).pushNamed(
                        '/class-leaderboard',
                        arguments: {
                          'classGroup': classGroup,
                          'students': _students,
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'ENROLLED STUDENTS (${_students.length})',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .05,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _students.isEmpty
                        ? const Center(
                            child: Text(
                              'No students enrolled yet.\nShare the join code with your class.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
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
                              return InkWell(
                                onTap: () =>
                                    Navigator.of(context).pushNamed(
                                  '/teacher-student-progress',
                                  arguments: {
                                    'classGroup': classGroup,
                                    'student': student,
                                  },
                                ),
                                borderRadius:
                                    BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                        color:
                                            const Color(0xFFE9DCBE)),
                                  ),
                                  child: Row(
                                    children: [
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
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              student.displayName,
                                              style: const TextStyle(
                                                fontFamily: 'Nunito',
                                                fontWeight:
                                                    FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'Grade ${student.gradeLevel}',
                                              style: const TextStyle(
                                                fontFamily: 'Nunito',
                                                fontSize: 11,
                                                color:
                                                    Color(0xFF6B7878),
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
                                          fontSize: 12,
                                          color: Color(0xFFE8A93B),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Color(0xFF6B7878),
                                        size: 18,
                                      ),
                                    ],
                                  ),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9DCBE)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFE8A93B)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF2E3A3A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}