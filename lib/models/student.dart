class Student {
  final int? id;
  final String username;
  final String passwordHash;
  final String displayName;
  final int gradeLevel;
  final String? pinHash;
  final bool isLinked; // true if registered by a parent, false if solo
  final int? parentId; // null if solo student
  final int totalPoints;
  final String createdAt;
  final String? firebaseUid;

  Student({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.displayName,
    required this.gradeLevel,
    this.pinHash,
    this.isLinked = false,
    this.parentId,
    this.totalPoints = 0,
    required this.createdAt,
    this.firebaseUid,
  });

  // Converts a Student object into a Map, which is what sqflite
  // needs to actually write a row into the database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'display_name': displayName,
      'grade_level': gradeLevel,
      'pin_hash': pinHash,
      'is_linked': isLinked ? 1 : 0, // SQLite has no true boolean type
      'parent_id': parentId,
      'total_points': totalPoints,
      'created_at': createdAt,
      'firebase_uid': firebaseUid,
    };
  }

  // Converts a Map (a row read back from the database) into
  // a proper Student object we can use in our app
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      displayName: map['display_name'] as String,
      gradeLevel: map['grade_level'] as int,
      pinHash: map['pin_hash'] as String?,
      isLinked: (map['is_linked'] as int) == 1,
      parentId: map['parent_id'] as int?,
      totalPoints: map['total_points'] as int,
      createdAt: map['created_at'] as String,
    );
  }
}