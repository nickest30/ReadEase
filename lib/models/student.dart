class Student {
  final int? id;
  final String username;
  final String? passwordHash;                  // ← was required, now nullable
  final String displayName;
  final int gradeLevel;
  final String? pinHash;
  final bool isLinked;
  final int? parentId;
  final String? parentFirebaseUid;             // NEW — string, replaces hash hack
  final int totalPoints;
  final String? recoveryEmail;                 // NEW
  final bool recoveryEmailVerified;            // NEW
  final String createdAt;
  final String? firebaseUid;
  final String? classFirestoreId;
  final String? className;
  final String? lastSyncedAt;
  final bool pendingSync;

  Student({
    this.id,
    required this.username,
    this.passwordHash,                          // ← not required anymore
    required this.displayName,
    required this.gradeLevel,
    this.pinHash,
    this.isLinked = false,
    this.parentId,
    this.parentFirebaseUid,                     // NEW
    this.totalPoints = 0,
    this.recoveryEmail,                         // NEW
    this.recoveryEmailVerified = false,         // NEW
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
      'parent_firebase_uid': parentFirebaseUid,
      'total_points': totalPoints,
      'recovery_email': recoveryEmail,
      'recovery_email_verified': recoveryEmailVerified ? 1 : 0,
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
      passwordHash: map['password_hash'] as String?,
      displayName: map['display_name'] as String,
      gradeLevel: map['grade_level'] as int,
      pinHash: map['pin_hash'] as String?,
      isLinked: (map['is_linked'] as int?) == 1,
      parentId: map['parent_id'] as int?,
      parentFirebaseUid: map['parent_firebase_uid'] as String?,
      totalPoints: (map['total_points'] as int?) ?? 0,
      recoveryEmail: map['recovery_email'] as String?,
      recoveryEmailVerified:
          ((map['recovery_email_verified'] as int?) ?? 0) == 1,
      createdAt: map['created_at'] as String,
      firebaseUid: map['firebase_uid'] as String?,
      classFirestoreId: map['class_firestore_id'] as String?,
      className: map['class_name'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      pendingSync: ((map['pending_sync'] as int?) ?? 0) == 1,
    );
  }

  Student copyWith({
    String? passwordHash,
    String? pinHash,
    int? totalPoints,
    String? parentFirebaseUid,
    String? recoveryEmail,
    bool? recoveryEmailVerified,
    String? firebaseUid,
    String? classFirestoreId,
    String? className,
    String? lastSyncedAt,
    bool? pendingSync,
  }) {
    return Student(
      id: id,
      username: username,
      passwordHash: passwordHash ?? this.passwordHash,
      displayName: displayName,
      gradeLevel: gradeLevel,
      pinHash: pinHash ?? this.pinHash,
      isLinked: isLinked,
      parentId: parentId,
      parentFirebaseUid: parentFirebaseUid ?? this.parentFirebaseUid,
      totalPoints: totalPoints ?? this.totalPoints,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      recoveryEmailVerified:
          recoveryEmailVerified ?? this.recoveryEmailVerified,
      createdAt: createdAt,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      classFirestoreId: classFirestoreId ?? this.classFirestoreId,
      className: className ?? this.className,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}