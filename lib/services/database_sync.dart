part of 'database_service.dart';

extension DatabaseSync on DatabaseService {
  Future<bool> markResultSynced(int resultId) async {
    final db = await database;
    final rows = await db.update('quiz_results', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [resultId]);
    return rows > 0;
  }

  Future<List<QuizResult>> getPendingSyncResults(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'quiz_results',
      where: 'student_id = ? AND synced_to_cloud = 0',
      whereArgs: [studentId],
      orderBy: 'completed_at ASC',
    );
    return maps.map((m) => QuizResult.fromMap(m)).toList();
  }

  Future<List<QuizAttempt>> getPendingSyncAttempts(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'quiz_attempts',
      where: 'student_id = ? AND synced_to_cloud = 0',
      whereArgs: [studentId],
      orderBy: 'completed_at ASC',
    );
    return maps.map((m) => QuizAttempt.fromMap(m)).toList();
  }

  Future<List<QuizAttempt>> getAttemptsForStudent(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'quiz_attempts',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'completed_at DESC',
    );
    return maps.map((m) => QuizAttempt.fromMap(m)).toList();
  }

  Future<bool> markAttemptSynced(int attemptId) async {
    final db = await database;
    final rows = await db.update('quiz_attempts', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [attemptId]);
    return rows > 0;
  }

  Future<List<AchievementBadge>> getPendingSyncBadges(int studentId) async {
    final db = await database;
    final maps = await db.query('badges', where: 'student_id = ? AND synced_to_cloud = 0', whereArgs: [studentId]);
    return maps.map((m) => AchievementBadge.fromMap(m)).toList();
  }

  Future<bool> markBadgeSynced(int badgeId) async {
    final db = await database;
    final rows = await db.update('badges', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [badgeId]);
    return rows > 0;
  }

  Future<List<WordMastery>> getMasteryForStudent(int studentId) async {
    final db = await database;
    final maps = await db.query('word_mastery', where: 'student_id = ?', whereArgs: [studentId]);
    return maps.map((m) => WordMastery.fromMap(m)).toList();
  }

  Future<List<WordEncounter>> getEncountersForStudent(int studentId) async {
    final db = await database;
    final maps = await db.query('word_encounters', where: 'student_id = ?', whereArgs: [studentId]);
    return maps.map((m) => WordEncounter.fromMap(m)).toList();
  }

  Future<List<StarredWord>> getStarredWordsForStudent(int studentId) async {
    final db = await database;
    final maps = await db.query('starred_words', where: 'student_id = ?', whereArgs: [studentId]);
    return maps.map((m) => StarredWord.fromMap(m)).toList();
  }

  Future<void> upsertWordMastery({
    required int studentId,
    required int wordId,
    required int correctCount,
    required int wrongCount,
    String? masteredAt,
  }) async {
    final db = await database;
    await db.rawInsert('''
      INSERT INTO word_mastery
        (student_id, word_id, correct_count, wrong_count, mastered_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(student_id, word_id) DO UPDATE SET
        correct_count = MAX(correct_count, excluded.correct_count),
        wrong_count   = MAX(wrong_count, excluded.wrong_count),
        mastered_at   = COALESCE(mastered_at, excluded.mastered_at)
    ''', [studentId, wordId, correctCount, wrongCount, masteredAt]);
  }

  Future<void> upsertWordEncounter({
    required int studentId,
    required int wordId,
    required String firstSeenAt,
    required int timesSeen,
  }) async {
    final db = await database;
    await db.rawInsert('''
      INSERT INTO word_encounters
        (student_id, word_id, first_seen_at, times_seen)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(student_id, word_id) DO UPDATE SET
        times_seen = MAX(times_seen, excluded.times_seen)
    ''', [studentId, wordId, firstSeenAt, timesSeen]);
  }

  Future<void> upsertStarredWord({
    required int studentId,
    required int wordId,
    required String starredAt,
  }) async {
    final db = await database;
    await db.insert(
      'starred_words',
      {'student_id': studentId, 'word_id': wordId, 'starred_at': starredAt},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static const int kMaxLoginAttempts = 5;
  static const int kMaxPinAttempts = 5;
  static const Duration kRateLimitWindow = Duration(minutes: 15);
  static const Duration kPinLockWindow = Duration(minutes: 3);

  Future<void> recordLoginAttempt({required String identifier, required bool success}) async {
    final db = await database;
    await db.insert('login_attempts', {
      'identifier': identifier.toLowerCase(),
      'attempt_at': DateTime.now().toIso8601String(),
      'success': success ? 1 : 0,
    });
  }

  Future<bool> isLoginRateLimited(String identifier) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(kRateLimitWindow).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT COUNT(*) as count FROM login_attempts
      WHERE identifier = ? AND attempt_at > ? AND success = 0
    ''', [identifier.toLowerCase(), cutoff]);
    final count = Sqflite.firstIntValue(rows) ?? 0;
    return count >= kMaxLoginAttempts;
  }

  Future<Duration?> loginRateLimitRemaining(String identifier) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(kRateLimitWindow).toIso8601String();
    final rows = await db.query(
      'login_attempts',
      columns: ['attempt_at'],
      where: 'identifier = ? AND attempt_at > ? AND success = 0',
      whereArgs: [identifier.toLowerCase(), cutoff],
      orderBy: 'attempt_at DESC',
    );
    if (rows.length < kMaxLoginAttempts) return null;
    final mostRecentRaw = rows.first['attempt_at'] as String?;
    if (mostRecentRaw == null) return null;
    final mostRecent = DateTime.tryParse(mostRecentRaw);
    if (mostRecent == null) return null;
    final expiry = mostRecent.add(kRateLimitWindow);
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Future<void> clearLoginAttempts(String identifier) async {
    final db = await database;
    await db.delete(
      'login_attempts',
      where: 'identifier = ? AND success = 0',
      whereArgs: [identifier.toLowerCase()],
    );
  }

  Future<void> recordPinAttempt({required int studentLocalId, required bool success}) async {
    final db = await database;
    await db.insert('pin_attempts', {
      'student_local_id': studentLocalId,
      'attempt_at': DateTime.now().toIso8601String(),
      'success': success ? 1 : 0,
    });
  }

  Future<bool> isPinRateLimited(int studentLocalId) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(kPinLockWindow).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT COUNT(*) as count FROM pin_attempts
      WHERE student_local_id = ? AND attempt_at > ? AND success = 0
    ''', [studentLocalId, cutoff]);
    final count = Sqflite.firstIntValue(rows) ?? 0;
    return count >= kMaxPinAttempts;
  }

  Future<Duration?> pinLockRemaining(int studentLocalId) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(kPinLockWindow).toIso8601String();
    final rows = await db.query(
      'pin_attempts',
      columns: ['attempt_at'],
      where: 'student_local_id = ? AND attempt_at > ? AND success = 0',
      whereArgs: [studentLocalId, cutoff],
      orderBy: 'attempt_at DESC',
    );
    if (rows.length < kMaxPinAttempts) return null;
    final mostRecentRaw = rows.first['attempt_at'] as String?;
    if (mostRecentRaw == null) return null;
    final mostRecent = DateTime.tryParse(mostRecentRaw);
    if (mostRecent == null) return null;
    final expiry = mostRecent.add(kPinLockWindow);
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Future<void> clearPinAttempts(int studentLocalId) async {
    final db = await database;
    await db.delete(
      'pin_attempts',
      where: 'student_local_id = ? AND success = 0',
      whereArgs: [studentLocalId],
    );
  }

  Future<void> pruneOldAttempts() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
    await db.delete('login_attempts', where: 'attempt_at < ?', whereArgs: [cutoff]);
    await db.delete('pin_attempts', where: 'attempt_at < ?', whereArgs: [cutoff]);
  }
}