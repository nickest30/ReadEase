class Student {
  final int? id;
  final String username;
  final String passwordHash;
  final String displayName;
  final int gradeLevel;
  final String? pinHash;
  final bool isLinked;
  final int? parentId;
  final int totalPoints;
  final String createdAt;
  final String? firebaseUid;
  final String? classFirestoreId;
  final String? className;
  final String? lastSyncedAt;    // NEW
  final bool pendingSync;        // NEW

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
    this.classFirestoreId,
    this.className,
    this.lastSyncedAt,
    this.pendingSync = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'display_name': displayName,
      'grade_level': gradeLevel,
      'pin_hash': pinHash,
      'is_linked': isLinked ? 1 : 0,
      'parent_id': parentId,
      'total_points': totalPoints,
      'created_at': createdAt,
      'firebase_uid': firebaseUid,
      'class_firestore_id': classFirestoreId,
      'class_name': className,
      'last_synced_at': lastSyncedAt,
      'pending_sync': pendingSync ? 1 : 0,
    };
  }

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
      firebaseUid: map['firebase_uid'] as String?,
      classFirestoreId: map['class_firestore_id'] as String?,
      className: map['class_name'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      pendingSync: ((map['pending_sync'] as int?) ?? 0) == 1,
    );
  }
}