class QuizResult {
  final int? id;
  final int studentId;
  final int gradeLevel;
  final String difficulty;
  final int score;
  final int totalQuestions;
  final int pointsEarned;
  final String completedAt;
  final String? wrongWordIds; // JSON array string like "[3,7,12]"

  QuizResult({
    this.id,
    required this.studentId,
    required this.gradeLevel,
    required this.difficulty,
    required this.score,
    required this.totalQuestions,
    required this.pointsEarned,
    required this.completedAt,
    this.wrongWordIds,
  });

  double get accuracyRate => totalQuestions == 0 ? 0 : score / totalQuestions;
  bool get isPassing => accuracyRate >= 0.70;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'grade_level': gradeLevel,
      'difficulty': difficulty,
      'score': score,
      'total_questions': totalQuestions,
      'points_earned': pointsEarned,
      'completed_at': completedAt,
      'wrong_word_ids': wrongWordIds,
    };
  }

  factory QuizResult.fromMap(Map<String, dynamic> map) {
    return QuizResult(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      gradeLevel: map['grade_level'] as int,
      difficulty: map['difficulty'] as String,
      score: map['score'] as int,
      totalQuestions: map['total_questions'] as int,
      pointsEarned: map['points_earned'] as int,
      completedAt: map['completed_at'] as String,
      wrongWordIds: map['wrong_word_ids'] as String?,
    );
  }
}