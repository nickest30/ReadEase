import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedTab = 0; // 0=local, 1=class, 2=global

  List<Map<String, dynamic>> _localEntries = [];
  bool _loadingLocal = true;

  List<Map<String, dynamic>> _classEntries = [];
  bool _loadingClass = false;
  bool _classAttempted = false;

  List<Map<String, dynamic>> _globalEntries = [];
  bool _loadingGlobal = false;
  bool _globalAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocal());
  }

  // ─────────────────────────────────────────────────────────
  // Data loaders
  // ─────────────────────────────────────────────────────────

  Future<void> _loadLocal() async {
    final students = await DatabaseService.instance.getAllStudents();
    if (!mounted) return;

    final entries = students.map((s) {
      return {
        'uid': s.firebaseUid ?? 'local-${s.id}',
        'displayName': s.displayName,
        'totalPoints': s.totalPoints,
        'gradeLevel': s.gradeLevel,
        'badgeCount': 0,
        'isCurrentUser': false,
      };
    }).toList()
      ..sort((a, b) =>
          (b['totalPoints'] as int).compareTo(a['totalPoints'] as int));

    setState(() {
      _localEntries = entries;
      _loadingLocal = false;
    });
  }

  Future<void> _loadClass() async {
    if (_loadingClass) return;

    final student = context.read<StudentProvider>().currentStudent;
    final isOnline = context.read<ConnectivityProvider>().isOnline;

    setState(() {
      _loadingClass = true;
      _classAttempted = true;
    });

    // No class joined yet
    if (student?.classFirestoreId == null ||
        student!.classFirestoreId!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _classEntries = [];
        _loadingClass = false;
      });
      return;
    }

    // Offline — can't fetch class leaderboard
    if (!isOnline) {
      if (!mounted) return;
      setState(() {
        _classEntries = [];
        _loadingClass = false;
      });
      return;
    }

    final entries = await FirestoreService.instance.getClassLeaderboard(
      classId: student.classFirestoreId!,
    );

    if (!mounted) return;
    setState(() {
      _classEntries = entries;
      _loadingClass = false;
    });
  }

  Future<void> _loadGlobal() async {
    if (_loadingGlobal) return;

    if (!context.read<ConnectivityProvider>().isOnline) {
      setState(() {
        _globalEntries = [];
        _globalAttempted = true;
      });
      return;
    }

    setState(() {
      _loadingGlobal = true;
      _globalAttempted = true;
    });

    final entries = await FirestoreService.instance.getGlobalLeaderboard();

    if (!mounted) return;
    setState(() {
      _globalEntries = entries;
      _loadingGlobal = false;
    });
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;

    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/student-profile-list',
            ModalRoute.withName('/role-selection'),
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Leaderboard', style: AppText.h2),
                        SizedBox(height: 2),
                        Text('See how you rank', style: AppText.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Local',
                      selected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                    _TabButton(
                      label: 'Class',
                      selected: _selectedTab == 1,
                      onTap: () {
                        setState(() => _selectedTab = 1);
                        if (!_classAttempted) _loadClass();
                      },
                    ),
                    _TabButton(
                      label: 'Global',
                      selected: _selectedTab == 2,
                      onTap: () {
                        setState(() => _selectedTab = 2);
                        if (!_globalAttempted) _loadGlobal();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Yse victory centered
            Image.asset(
              'assets/images/mascot/yse_victory.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentYellow,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 80,
                  color: AppColors.accentYellow,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Tab content
            Expanded(
              child: _selectedTab == 0
                  ? _buildLocalTab(student)
                  : _selectedTab == 1
                      ? _buildClassTab(student)
                      : _buildGlobalTab(student),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Local tab
  // ─────────────────────────────────────────────────────────

  Widget _buildLocalTab(Student currentStudent) {
    if (_loadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_localEntries.isEmpty) {
      return _buildEmptyState(
        icon: Icons.leaderboard_rounded,
        title: 'No profiles yet',
        subtitle: 'Create a profile to see rankings.',
      );
    }

    final entries = _localEntries.map((e) {
      e['isCurrentUser'] =
          e['uid'] == (currentStudent.firebaseUid ?? 'local-${currentStudent.id}');
      return e;
    }).toList();

    return _buildRankedContent(entries);
  }

  // ─────────────────────────────────────────────────────────
  // Class tab
  // ─────────────────────────────────────────────────────────

  Widget _buildClassTab(Student currentStudent) {
    // No class joined
    if (currentStudent.classFirestoreId == null ||
        currentStudent.classFirestoreId!.isEmpty) {
      return _buildJoinClassPrompt();
    }

    // Class banner — shows which class the student is in
    final classBanner = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.accentPurple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: AppColors.accentPurple.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.class_rounded,
              color: AppColors.accentPurple,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR CLASS',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textPurple,
                    ),
                  ),
                  Text(
                    currentStudent.className ?? 'Class',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (_loadingClass) {
      return Column(
        children: [
          classBanner,
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    if (!isOnline) {
      return Column(
        children: [
          classBanner,
          Expanded(
            child: _buildEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'You\'re offline',
              subtitle: 'Connect to see your class leaderboard.',
            ),
          ),
        ],
      );
    }

    if (_classEntries.isEmpty) {
      return Column(
        children: [
          classBanner,
          Expanded(
            child: _buildEmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No rankings yet',
              subtitle: 'Take a quiz to appear on the board!',
            ),
          ),
        ],
      );
    }

    final entries = _classEntries.map((e) {
      e['isCurrentUser'] = e['uid'] == currentStudent.firebaseUid;
      return e;
    }).toList();

    return Column(
      children: [
        classBanner,
        Expanded(
          child: _buildRankedContent(entries, refresh: _loadClass),
        ),
      ],
    );
  }


  Widget _buildJoinClassPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/mascot/yse_thinking.png',
              width: 140,
              height: 140,
              errorBuilder: (_, _, _) => const Icon(
                Icons.class_rounded,
                size: 80,
                color: AppColors.accentPurple,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No class yet',
              style: AppText.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Join a class with your teacher\'s code\nto see how you rank with classmates.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).pushNamed('/join-class');
                if (mounted) {
                  setState(() {
                    _classAttempted = false;
                    _classEntries = [];
                  });
                  _loadClass();
                }
              },
              icon: const Icon(Icons.group_add_rounded),
              label: const Text(
                'Join a Class',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Global tab
  // ─────────────────────────────────────────────────────────

  Widget _buildGlobalTab(Student currentStudent) {
    if (_loadingGlobal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_globalEntries.isEmpty) {
      final isOnline = context.watch<ConnectivityProvider>().isOnline;
      return _buildEmptyState(
        icon: isOnline
            ? Icons.emoji_events_outlined
            : Icons.cloud_off_rounded,
        title: isOnline ? 'No global rankings yet' : 'You\'re offline',
        subtitle: isOnline
            ? 'Be the first to make it to the top!'
            : 'Connect to see the global leaderboard.',
      );
    }

    final entries = _globalEntries.map((e) {
      e['isCurrentUser'] = e['uid'] == currentStudent.firebaseUid;
      return e;
    }).toList();

    return _buildRankedContent(entries, refresh: _loadGlobal);
  }

  // ─────────────────────────────────────────────────────────
  // Shared ranked content
  // ─────────────────────────────────────────────────────────

  Widget _buildRankedContent(
    List<Map<String, dynamic>> entries, {
    Future<void> Function()? refresh,
  }) {
    final body = Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        if (entries.isNotEmpty) _buildPodium(entries),
        const SizedBox(height: AppSpacing.lg),
        ...entries.asMap().entries.map((entry) {
          return _RankRow(rank: entry.key + 1, data: entry.value);
        }),
        const SizedBox(height: AppSpacing.xl),
      ],
    );

    if (refresh != null) {
      return RefreshIndicator(
        onRefresh: refresh,
        color: AppColors.accentTeal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: body,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: body,
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> entries) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (second != null)
            _PodiumEntry(
              rank: 2,
              data: second,
              height: 90,
              color: const Color(0xFF9E9E9E),
            ),
          if (first != null)
            _PodiumEntry(
              rank: 1,
              data: first,
              height: 120,
              color: AppColors.accentYellow,
            ),
          if (third != null)
            _PodiumEntry(
              rank: 3,
              data: third,
              height: 70,
              color: const Color(0xFFCD7F32),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppText.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Podium entry
// ─────────────────────────────────────────────────────────

class _PodiumEntry extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  final double height;
  final Color color;

  const _PodiumEntry({
    required this.rank,
    required this.data,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['displayName'] as String?) ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final points = data['totalPoints'] ?? 0;
    final isCurrentUser = data['isCurrentUser'] == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1)
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.accentYellow,
            size: 28,
          )
        else
          const SizedBox(height: 28),
        const SizedBox(height: 4),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrentUser ? AppColors.accentTeal : Colors.white,
              width: isCurrentUser ? 3 : 2,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            name,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$points pts',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: height * 0.4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Rank row
// ─────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;

  const _RankRow({required this.rank, required this.data});

  Color _rankColor() {
    if (rank == 1) return AppColors.accentYellow;
    if (rank == 2) return const Color(0xFF9E9E9E);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final name = (data['displayName'] as String?) ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final points = data['totalPoints'] ?? 0;
    final grade = data['gradeLevel'] ?? '?';
    final badgeCount = data['badgeCount'] ?? 0;
    final isCurrentUser = data['isCurrentUser'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.accentTeal.withValues(alpha: 0.15)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: isCurrentUser ? AppColors.accentTeal : AppColors.border,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _rankColor(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.accentTeal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '$name (you)' : name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text('Grade $grade', style: AppText.caption),
              ],
            ),
          ),
          if (badgeCount > 0) ...[
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.accentYellow,
                  size: 16,
                ),
                const SizedBox(width: 2),
                Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textYellow,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            '$points pts',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textYellow,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Tab button
// ─────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? AppColors.accentTeal : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}