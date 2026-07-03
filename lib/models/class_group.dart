class ClassGroup {
  final int? id;
  final int teacherId;
  final String className;
  final int gradeLevel;
  final String joinCode;
  final String createdAt;

  ClassGroup({
    this.id,
    required this.teacherId,
    required this.className,
    required this.gradeLevel,
    required this.joinCode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'class_name': className,
      'grade_level': gradeLevel,
      'join_code': joinCode,
      'created_at': createdAt,
    };
  }

  factory ClassGroup.fromMap(Map<String, dynamic> map) {
    return ClassGroup(
      id: map['id'] as int?,
      teacherId: map['teacher_id'] as int,
      className: map['class_name'] as String,
      gradeLevel: map['grade_level'] as int,
      joinCode: map['join_code'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
