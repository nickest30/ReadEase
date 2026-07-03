import 'package:flutter/material.dart';
import '../../models/teacher.dart';
import '../../models/class_group.dart';
import '../../services/database_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends State<TeacherDashboardScreen> {
  List<ClassGroup> _classes = [];
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadClasses();
    }
  }

  Future<void> _loadClasses() async {
    final teacher =
        ModalRoute.of(context)!.settings.arguments as Teacher;
    final classes = await DatabaseService.instance
        .getClassGroupsByTeacher(teacher.id!);
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final teacher =
        ModalRoute.of(context)!.settings.arguments as Teacher;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Hello, ${teacher.fullName.split(' ').first}!',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),
              Text(
                teacher.schoolName,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'My Classes',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E3A3A),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _classes.isEmpty
                        ? const Center(
                            child: Text(
                              'No classes yet.\nTap "Create Class" to get started.',
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
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: _classes.length,
                            itemBuilder: (context, index) {
                              final group = _classes[index];
                              return _ClassCard(
                                group: group,
                                onTap: () async {
                                  await Navigator.of(context).pushNamed(
                                    '/class-overview',
                                    arguments: {
                                      'teacher': teacher,
                                      'classGroup': group,
                                    },
                                  );
                                  _loadClasses();
                                },
                              );
                            },
                          ),
              ),

              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).pushNamed(
                      '/create-class',
                      arguments: teacher,
                    );
                    _loadClasses();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Create Class',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A93B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6F61),
                    side: const BorderSide(color: Color(0xFFFF6F61)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassGroup group;
  final VoidCallback onTap;

  const _ClassCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9DCBE)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.class_rounded,
              color: Color(0xFFE8A93B),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              group.className,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF2E3A3A),
              ),
            ),
            Text(
              'Grade ${group.gradeLevel}',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: Color(0xFF6B7878),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF0D9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                group.joinCode,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE8A93B),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}