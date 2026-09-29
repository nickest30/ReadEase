class AchievementBadge {
  final int? id;
  final int studentId;
  final int gradeLevel;
  final String difficulty;
  final String badgeName;
  final int pointsEarned;
  final String earnedAt;
  final bool syncedToCloud;

  AchievementBadge({
    this.id,
    required this.studentId,
    required this.gradeLevel,
    required this.difficulty,
    required this.badgeName,
    required this.pointsEarned,
    required this.earnedAt,
    this.syncedToCloud = false,
  });

  String get key => '$gradeLevel-$difficulty';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'grade_level': gradeLevel,
      'difficulty': difficulty,
      'badge_name': badgeName,
      'points_earned': pointsEarned,
      'earned_at': earnedAt,
      'synced_to_cloud': syncedToCloud ? 1 : 0,
    };
  }

  factory AchievementBadge.fromMap(Map<String, dynamic> map) {
    return AchievementBadge(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      gradeLevel: map['grade_level'] as int,
      difficulty: map['difficulty'] as String,
      badgeName: map['badge_name'] as String,
      pointsEarned: map['points_earned'] as int,
      earnedAt: map['earned_at'] as String,
      syncedToCloud: ((map['synced_to_cloud'] as int?) ?? 0) == 1,
    );
  }

  /// Get the display name for a (grade, difficulty) combination.
  static String nameFor(int gradeLevel, String difficulty) {
    switch (gradeLevel) {
      case 1:
        if (difficulty == 'easy') return 'Sprout Reader';
        if (difficulty == 'medium') return 'Growing Reader';
        return 'Strong Reader';
      case 2:
        if (difficulty == 'easy') return 'Story Starter';
        if (difficulty == 'medium') return 'Story Explorer';
        return 'Story Master';
      case 3:
        if (difficulty == 'easy') return 'Word Builder';
        if (difficulty == 'medium') return 'Sentence Solver';
        return 'Comprehension Champ';
      case 4:
        if (difficulty == 'easy') return 'Meaning Hunter';
        if (difficulty == 'medium') return 'Logic Thinker';
        return 'Insight Master';
      case 5:
        if (difficulty == 'easy') return 'Vocab Virtuoso';
        if (difficulty == 'medium') return 'Critical Reader';
        return 'Scholar';
      case 6:
        if (difficulty == 'easy') return 'Passage Pilot';
        if (difficulty == 'medium') return 'Advanced Analyst';
        return 'Reading Champion';
      default:
        return 'Badge';
    }
  }

  /// Asset path for the badge image (e.g. badge_g1_easy.png)
  static String imagePathFor(int gradeLevel, String difficulty) {
    return 'assets/images/badge/badge_g${gradeLevel}_$difficulty.png';
  }

  /// Asset path for special badges
  static String specialImagePath(String specialKey) {
    return 'assets/images/badge/badge_special_$specialKey.png';
  }
}