part of 'database_service.dart';

extension DatabaseStudents on DatabaseService {
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final maps = await db.query('students');
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  Future<Student?> getStudentByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'students', where: 'username = ?', whereArgs: [username],
    );
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  Future<Student?> getStudentById(int id) async {
    final db = await database;
    final maps = await db.query('students', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  Future<int> updatePin(int studentId, String pinHash) async {
    final db = await database;
    return await db.update(
      'students', {'pin_hash': pinHash}, where: 'id = ?', whereArgs: [studentId],
    );
  }

  Future<bool> updateStudentDisplayName(int studentId, String displayName) async {
    final db = await database;
    final rows = await db.update(
      'students', {'display_name': displayName}, where: 'id = ?', whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<bool> updateStudentAvatar(int studentId, int avatarIndex) async {
    final db = await database;
    final safe = avatarIndex.clamp(1, 12);
    final rows = await db.update(
      'students', {'avatar_index': safe}, where: 'id = ?', whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<bool> updateStudentUsername(int studentId, String username) async {
    final db = await database;
    final rows = await db.update(
      'students', {'username': username}, where: 'id = ?', whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<bool> updateStudentFirebaseUid(int studentId, String firebaseUid) async {
    final db = await database;
    final rows = await db.update(
      'students', {'firebase_uid': firebaseUid}, where: 'id = ?', whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<int> computePointsDeltaForBatch({
    required int studentId,
    required int batchId,
    required int newScore,
    int pointsPerCorrect = 5,
  }) async {
    final db = await database;
    final maps = await db.query(
      'quiz_attempts',
      columns: ['score'],
      where: 'student_id = ? AND batch_id = ?',
      whereArgs: [studentId, batchId],
      orderBy: 'score DESC',
      limit: 1,
    );
    final int previousBest = maps.isEmpty ? 0 : (maps.first['score'] as int);
    final int newPoints = newScore * pointsPerCorrect;
    final int previousBestPoints = previousBest * pointsPerCorrect;
    final int delta = newPoints - previousBestPoints;
    return delta > 0 ? delta : 0;
  }

  Future<int> computePointsDelta({
    required int studentId,
    required int gradeLevel,
    required String difficulty,
    required int newScore,
    int pointsPerCorrect = 5,
  }) async {
    final db = await database;
    final maps = await db.query(
      'quiz_results',
      columns: ['score'],
      where: 'student_id = ? AND grade_level = ? AND difficulty = ?',
      whereArgs: [studentId, gradeLevel, difficulty],
      orderBy: 'score DESC',
      limit: 1,
    );
    final int previousBest = maps.isEmpty ? 0 : (maps.first['score'] as int);
    final int newPoints = newScore * pointsPerCorrect;
    final int previousBestPoints = previousBest * pointsPerCorrect;
    final int delta = newPoints - previousBestPoints;
    return delta > 0 ? delta : 0;
  }

  Future<int> addPoints(int studentId, int points) async {
    final db = await database;
    final student = await getStudentById(studentId);
    if (student == null) return 0;
    return await db.update(
      'students',
      {'total_points': student.totalPoints + points},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  Future<bool> updateStudentClass(
    int studentId,
    String classFirestoreId,
    String className,
  ) async {
    final db = await database;
    final rows = await db.update(
      'students',
      {
        'class_firestore_id': classFirestoreId,
        'class_name': className,
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<List<Word>> getWeakWords(int studentId, {int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'quiz_results',
      columns: ['wrong_word_ids'],
      where: 'student_id = ? AND wrong_word_ids IS NOT NULL AND wrong_word_ids != ""',
      whereArgs: [studentId],
      orderBy: 'completed_at DESC',
    );
    if (rows.isEmpty) return [];

    final Set<int> uniqueIds = {};
    for (final row in rows) {
      final raw = row['wrong_word_ids'] as String?;
      if (raw == null || raw.isEmpty) continue;
      final cleaned = raw.replaceAll('[', '').replaceAll(']', '');
      if (cleaned.isEmpty) continue;
      for (final part in cleaned.split(',')) {
        final id = int.tryParse(part.trim());
        if (id != null) uniqueIds.add(id);
        if (uniqueIds.length >= limit) break;
      }
      if (uniqueIds.length >= limit) break;
    }
    if (uniqueIds.isEmpty) return [];

    final placeholders = List.filled(uniqueIds.length, '?').join(',');
    final wordRows = await db.query(
      'words',
      where: 'id IN ($placeholders)',
      whereArgs: uniqueIds.toList(),
    );
    return wordRows.map((m) => Word.fromMap(m)).toList();
  }

  Future<bool> markStudentPendingSync(int studentId) async {
    final db = await database;
    final rows = await db.update(
      'students', {'pending_sync': 1}, where: 'id = ?', whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<bool> markStudentSynced(int studentId) async {
    final db = await database;
    final rows = await db.update(
      'students',
      {'pending_sync': 0, 'last_synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<List<Student>> getPendingSyncStudents() async {
    final db = await database;
    final maps = await db.query('students', where: 'pending_sync = 1');
    return maps.map((m) => Student.fromMap(m)).toList();
  }

  Future<bool> updateStudentParent(
    int studentId,
    String parentFirebaseUid,
    bool isLinked,
  ) async {
    final db = await database;
    final rows = await db.update(
      'students',
      {
        'parent_id': parentFirebaseUid.hashCode,
        'is_linked': isLinked ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<bool> updateStudentFromCloud({
    required int studentId,
    required String displayName,
    required int gradeLevel,
    required int totalPoints,
    String? pinHash,
    String? parentFirebaseUid,
    String? recoveryEmail,
    String? className,
    String? classFirestoreId,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'display_name': displayName,
      'grade_level': gradeLevel,
      'total_points': totalPoints,
      'last_synced_at': DateTime.now().toIso8601String(),
    };
    if (pinHash != null) updates['pin_hash'] = pinHash;
    if (parentFirebaseUid != null) updates['parent_firebase_uid'] = parentFirebaseUid;
    if (recoveryEmail != null) updates['recovery_email'] = recoveryEmail;
    if (className != null) updates['class_name'] = className;
    if (classFirestoreId != null) updates['class_firestore_id'] = classFirestoreId;
    final rows = await db.update('students', updates, where: 'id = ?', whereArgs: [studentId]);
    return rows > 0;
  }

  Future<bool> updateStudentPinHash(int studentId, String pinHash) async {
    final db = await database;
    final rows = await db.update('students', {'pin_hash': pinHash}, where: 'id = ?', whereArgs: [studentId]);
    return rows > 0;
  }

  Future<bool> updateStudentParentUid(
    int studentId,
    String parentFirebaseUid,
    bool isLinked,
  ) async {
    final db = await database;
    final updates = <String, dynamic>{
      'parent_firebase_uid': parentFirebaseUid,
      'is_linked': isLinked ? 1 : 0,
    };
    if (!isLinked || parentFirebaseUid.isEmpty) {
      updates['parent_id'] = null;
    }
    final rows = await db.update('students', updates, where: 'id = ?', whereArgs: [studentId]);
    return rows > 0;
  }

  Future<bool> updateStudentRecoveryEmail(int studentId, String? email) async {
    final db = await database;
    final rows = await db.update('students', {'recovery_email': email}, where: 'id = ?', whereArgs: [studentId]);
    return rows > 0;
  }
}