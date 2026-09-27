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

  /// Unique key for this badge per student
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

  /// Get the badge name for a given (grade, difficulty).
  static String nameFor(int gradeLevel, String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Easy Reader';
      case 'medium':
        return 'Medium Master';
      case 'hard':
        return 'Hard Hero';
      default:
        return 'Grade $gradeLevel $difficulty';
    }
  }
}