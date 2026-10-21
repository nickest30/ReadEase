part of 'database_service.dart';

extension DatabaseRoles on DatabaseService {
  Future<int> insertParent(Parent parent) async {
    final db = await database;
    return await db.insert('parents', parent.toMap());
  }

  Future<List<Parent>> getAllParents() async {
    final db = await database;
    final maps = await db.query('parents');
    return maps.map((m) => Parent.fromMap(m)).toList();
  }

  Future<Parent?> getParentByUsername(String username) async {
    final db = await database;
    final maps = await db.query('parents', where: 'username = ?', whereArgs: [username]);
    if (maps.isEmpty) return null;
    return Parent.fromMap(maps.first);
  }

  Future<bool> updateParentFirebaseUid(int parentId, String firebaseUid) async {
    final db = await database;
    final rows = await db.update('parents', {'firebase_uid': firebaseUid}, where: 'id = ?', whereArgs: [parentId]);
    return rows > 0;
  }

  Future<Parent?> getParentById(int id) async {
    final db = await database;
    final maps = await db.query('parents', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Parent.fromMap(maps.first);
  }

  Future<List<Student>> getChildrenOfParent(int parentId) async {
    final db = await database;
    final maps = await db.query('students', where: 'parent_id = ? AND is_linked = 1', whereArgs: [parentId]);
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  Future<int> insertLinkedStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  Future<int> deleteStudent(int studentId) async {
    final db = await database;
    return await db.delete('students', where: 'id = ?', whereArgs: [studentId]);
  }

  Future<bool> markParentEmailVerified(int parentId) async {
    final db = await database;
    final rows = await db.update('parents', {'email_verified': 1}, where: 'id = ?', whereArgs: [parentId]);
    return rows > 0;
  }

  Future<bool> updateParentPhone(int parentId, String? phoneNumber, bool phoneVerified) async {
    final db = await database;
    final rows = await db.update(
      'parents',
      {'phone_number': phoneNumber, 'phone_verified': phoneVerified ? 1 : 0},
      where: 'id = ?',
      whereArgs: [parentId],
    );
    return rows > 0;
  }

  Future<bool> updateParentBackupCodeHash(int parentId, String hash) async {
    final db = await database;
    final rows = await db.update(
      'parents',
      {'backup_code_hash': hash, 'backup_code_used': 0},
      where: 'id = ?',
      whereArgs: [parentId],
    );
    return rows > 0;
  }

  Future<bool> updateParentPasswordHash(int parentId, String passwordHash) async {
    final db = await database;
    final rows = await db.update('parents', {'password_hash': passwordHash}, where: 'id = ?', whereArgs: [parentId]);
    return rows > 0;
  }

  Future<int> insertTeacher(Teacher teacher) async {
    final db = await database;
    return await db.insert('teachers', teacher.toMap());
  }

  Future<Teacher?> getTeacherByUsername(String username) async {
    final db = await database;
    final maps = await db.query('teachers', where: 'username = ?', whereArgs: [username]);
    if (maps.isEmpty) return null;
    return Teacher.fromMap(maps.first);
  }

  Future<List<Teacher>> getAllTeachers() async {
    final db = await database;
    final maps = await db.query('teachers');
    return maps.map((m) => Teacher.fromMap(m)).toList();
  }

  Future<bool> updateTeacherFirebaseUid(int teacherId, String firebaseUid) async {
    final db = await database;
    final rows = await db.update('teachers', {'firebase_uid': firebaseUid}, where: 'id = ?', whereArgs: [teacherId]);
    return rows > 0;
  }

  Future<Teacher?> getTeacherById(int id) async {
    final db = await database;
    final maps = await db.query('teachers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Teacher.fromMap(maps.first);
  }

  Future<bool> markTeacherEmailVerified(int teacherId) async {
    final db = await database;
    final rows = await db.update('teachers', {'email_verified': 1}, where: 'id = ?', whereArgs: [teacherId]);
    return rows > 0;
  }

  Future<bool> updateTeacherPhone(int teacherId, String? phoneNumber, bool phoneVerified) async {
    final db = await database;
    final rows = await db.update(
      'teachers',
      {'phone_number': phoneNumber, 'phone_verified': phoneVerified ? 1 : 0},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
    return rows > 0;
  }

  Future<bool> updateTeacherBackupCodeHash(int teacherId, String hash) async {
    final db = await database;
    final rows = await db.update(
      'teachers',
      {'backup_code_hash': hash, 'backup_code_used': 0},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
    return rows > 0;
  }

  Future<bool> updateTeacherPasswordHash(int teacherId, String passwordHash) async {
    final db = await database;
    final rows = await db.update('teachers', {'password_hash': passwordHash}, where: 'id = ?', whereArgs: [teacherId]);
    return rows > 0;
  }

  Future<int> insertClassGroup(ClassGroup group) async {
    final db = await database;
    return await db.insert('class_groups', group.toMap());
  }

  Future<List<ClassGroup>> getClassGroupsByTeacher(int teacherId) async {
    final db = await database;
    final maps = await db.query('class_groups', where: 'teacher_id = ?', whereArgs: [teacherId], orderBy: 'created_at DESC');
    return maps.map((map) => ClassGroup.fromMap(map)).toList();
  }

  Future<ClassGroup?> getClassGroupByJoinCode(String joinCode) async {
    final db = await database;
    final maps = await db.query('class_groups', where: 'join_code = ?', whereArgs: [joinCode]);
    if (maps.isEmpty) return null;
    return ClassGroup.fromMap(maps.first);
  }

  Future<ClassGroup?> getClassGroupById(int id) async {
    final db = await database;
    final maps = await db.query('class_groups', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ClassGroup.fromMap(maps.first);
  }

  Future<bool> updateClassGroupFirestoreId(int localId, String firestoreId) async {
    final db = await database;
    final rows = await db.update('class_groups', {'firestore_id': firestoreId}, where: 'id = ?', whereArgs: [localId]);
    return rows > 0;
  }

  Future<void> insertClassGroupIfMissing({
    required int teacherId,
    required String firestoreId,
    required String className,
    required int gradeLevel,
    required String joinCode,
  }) async {
    final db = await database;
    final existing = await db.query('class_groups', where: 'firestore_id = ?', whereArgs: [firestoreId], limit: 1);
    if (existing.isNotEmpty) return;
    await db.insert('class_groups', {
      'teacher_id': teacherId,
      'class_name': className,
      'grade_level': gradeLevel,
      'join_code': joinCode,
      'firestore_id': firestoreId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> enrollStudent(int classGroupId, int studentId) async {
    final db = await database;
    await db.insert('class_enrollments', {
      'class_group_id': classGroupId,
      'student_id': studentId,
      'enrolled_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Student>> getStudentsInClass(int classGroupId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.* FROM students s
      INNER JOIN class_enrollments ce ON ce.student_id = s.id
      WHERE ce.class_group_id = ?
      ORDER BY s.total_points DESC
    ''', [classGroupId]);
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  Future<bool> isStudentEnrolled(int classGroupId, int studentId) async {
    final db = await database;
    final maps = await db.query('class_enrollments', where: 'class_group_id = ? AND student_id = ?', whereArgs: [classGroupId, studentId]);
    return maps.isNotEmpty;
  }

  String generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    int seed = random;
    for (int i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      code += chars[seed % chars.length];
    }
    return code;
  }

  Future<void> insertLinkedChildIfMissing({
    required int parentId,
    required String firebaseUid,
    required String username,
    required String displayName,
    required int gradeLevel,
    required int totalPoints,
  }) async {
    final db = await database;
    final existing = await db.query('students', where: 'firebase_uid = ?', whereArgs: [firebaseUid], limit: 1);
    if (existing.isEmpty) {
      await db.insert('students', {
        'username': username,
        'password_hash': '',
        'display_name': displayName,
        'grade_level': gradeLevel,
        'is_linked': 1,
        'parent_id': parentId,
        'total_points': totalPoints,
        'firebase_uid': firebaseUid,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update(
        'students',
        {'display_name': displayName, 'grade_level': gradeLevel, 'total_points': totalPoints},
        where: 'firebase_uid = ?',
        whereArgs: [firebaseUid],
      );
    }
  }

  Future<bool> awardBadge(AchievementBadge badge) async {
    final db = await database;
    try {
      final id = await db.insert('badges', badge.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      return id > 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<AchievementBadge>> getBadgesForStudent(int studentId) async {
    final db = await database;
    final maps = await db.query('badges', where: 'student_id = ?', whereArgs: [studentId], orderBy: 'earned_at DESC');
    return maps.map((m) => AchievementBadge.fromMap(m)).toList();
  }
}