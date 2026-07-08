import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Student> _localStudents = [];
  List<Map<String, dynamic>> _globalEntries = [];
  bool _loadingLocal = true;
  bool _loadingGlobal = false;
  int _selectedTab = 0; // 0=local, 1=global

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final students = await DatabaseService.instance.getAllStudents();
    students.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    if (!mounted) return;
    setState(() {
      _localStudents = students;
      _loadingLocal = false;
    });
  }

  Future<void> _loadGlobal() async {
    setState(() => _loadingGlobal = true);
    try {
      final entries =
          await FirestoreService.instance.getGlobalLeaderboard();
      if (!mounted) return;
      setState(() {
        _globalEntries = entries;
        _loadingGlobal = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingGlobal = false);
    }
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

              // Tab selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9DCBE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Local',
                      selected: _selectedTab == 0,
                      onTap: () {
                        setState(() => _selectedTab = 0);
                      },
                    ),
                    _TabButton(
                      label: 'Class',
                      selected: _selectedTab == 1,
                      onTap: () {
                        setState(() => _selectedTab = 1);
                      },
                    ),
                    _TabButton(
                      label: 'Global',
                      selected: _selectedTab == 2,
                      onTap: () {
                        setState(() => _selectedTab = 2);
                        if (_globalEntries.isEmpty) _loadGlobal();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _selectedTab == 0
                    ? _buildLocalList(currentStudent)
                    : _selectedTab == 1
                        ? _buildClassPlaceholder()
                        : _buildGlobalList(currentStudent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalList(Student currentStudent) {
    if (_loadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_localStudents.isEmpty) {
      return const Center(
        child: Text(
          'No students yet.',
          style: TextStyle(
              fontFamily: 'Nunito', color: Color(0xFF6B7878)),
        ),
      );
    }
    return _buildRankedList(
      _localStudents
          .map((s) => {
                'uid': s.firebaseUid ?? s.id.toString(),
                'displayName': s.displayName,
                'totalPoints': s.totalPoints,
                'gradeLevel': s.gradeLevel,
                'isCurrentUser': s.id == currentStudent.id,
              })
          .toList(),
      currentStudentUid:
          currentStudent.firebaseUid ?? currentStudent.id.toString(),
    );
  }

  Widget _buildClassPlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Class leaderboard requires joining a class.\nGo to Settings → Join a Class.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            color: Color(0xFF6B7878),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalList(Student currentStudent) {
    if (_loadingGlobal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_globalEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No global entries yet\nor no internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: Color(0xFF6B7878),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadGlobal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2BAFA0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontFamily: 'Nunito'),
              ),
            ),
          ],
        ),
      );
    }
    return _buildRankedList(
      _globalEntries.map((e) => {
            ...e,
            'isCurrentUser': e['uid'] == currentStudent.firebaseUid,
          }).toList(),
      currentStudentUid: currentStudent.firebaseUid ?? '',
    );
  }

  Widget _buildRankedList(
    List<Map<String, dynamic>> entries, {
    required String currentStudentUid,
  }) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final rank = index + 1;
        final isCurrentUser =
            entry['isCurrentUser'] as bool? ?? false;

        Color rankColor = const Color(0xFF6B7878);
        if (rank == 1) rankColor = const Color(0xFFE8A93B);
        if (rank == 2) rankColor = const Color(0xFF9E9E9E);
        if (rank == 3) rankColor = const Color(0xFFCD7F32);

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? const Color(0xFFDCF1ED)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
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
                backgroundColor: const Color(0xFF2BAFA0),
                child: Text(
                  (entry['displayName'] as String)[0].toUpperCase(),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (entry['displayName'] as String) +
                          (isCurrentUser ? ' (you)' : ''),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF2E3A3A),
                      ),
                    ),
                    Text(
                      'Grade ${entry['gradeLevel']}',
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
                '${entry['totalPoints']} pts',
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
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected
                  ? const Color(0xFF2BAFA0)
                  : const Color(0xFF6B7878),
            ),
          ),
        ),
      ),
    );
  }
}