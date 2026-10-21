part of 'database_service.dart';

extension DatabaseProgress on DatabaseService {
  Future<void> recordWordEncounter(int studentId, int wordId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawInsert('''
      INSERT INTO word_encounters (student_id, word_id, first_seen_at, times_seen)
      VALUES (?, ?, ?, 1)
      ON CONFLICT(student_id, word_id) DO UPDATE SET
        times_seen = times_seen + 1
    ''', [studentId, wordId, now]);
  }

  Future<bool> updateWordMastery({
    required int studentId,
    required int wordId,
    required bool correct,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      'word_mastery',
      where: 'student_id = ? AND word_id = ?',
      whereArgs: [studentId, wordId],
      limit: 1,
    );
    if (maps.isEmpty) {
      final correctCount = correct ? 1 : 0;
      final wrongCount = correct ? 0 : 1;
      final masteredAt = correctCount >= 3 ? now : null;
      await db.insert('word_mastery', {
        'student_id': studentId,
        'word_id': wordId,
        'correct_count': correctCount,
        'wrong_count': wrongCount,
        'mastered_at': masteredAt,
      });
      return correctCount >= 3;
    }
    final existing = WordMastery.fromMap(maps.first);
    final newCorrect = existing.correctCount + (correct ? 1 : 0);
    final newWrong = existing.wrongCount + (correct ? 0 : 1);
    String? newMasteredAt = existing.masteredAt;
    bool justMastered = false;
    if (newMasteredAt == null && newCorrect >= 3) {
      newMasteredAt = now;
      justMastered = true;
    }
    await db.update(
      'word_mastery',
      {'correct_count': newCorrect, 'wrong_count': newWrong, 'mastered_at': newMasteredAt},
      where: 'student_id = ? AND word_id = ?',
      whereArgs: [studentId, wordId],
    );
    return justMastered;
  }

  Future<void> markWordMastered({required int studentId, required int wordId}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'word_mastery',
      where: 'student_id = ? AND word_id = ?',
      whereArgs: [studentId, wordId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('word_mastery', {
        'student_id': studentId,
        'word_id': wordId,
        'correct_count': 3,
        'wrong_count': 0,
        'mastered_at': now,
      });
    } else {
      await db.update(
        'word_mastery',
        {'correct_count': 3, 'mastered_at': now},
        where: 'student_id = ? AND word_id = ?',
        whereArgs: [studentId, wordId],
      );
    }
  }

  Future<void> starWord(int studentId, int wordId) async {
    final db = await database;
    await db.insert(
      'starred_words',
      {'student_id': studentId, 'word_id': wordId, 'starred_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unstarWord(int studentId, int wordId) async {
    final db = await database;
    await db.delete('starred_words', where: 'student_id = ? AND word_id = ?', whereArgs: [studentId, wordId]);
  }

  Future<List<StarredWord>> getStarredWords(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'starred_words',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'starred_at DESC',
    );
    return maps.map((m) => StarredWord.fromMap(m)).toList();
  }

  Future<void> recordBatchVisit(int studentId, int batchId) async {
    final db = await database;
    await db.insert(
      'batch_visits',
      {'student_id': studentId, 'batch_id': batchId, 'first_visit_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> hasVisitedBatch(int studentId, int batchId) async {
    final db = await database;
    final maps = await db.query(
      'batch_visits',
      where: 'student_id = ? AND batch_id = ?',
      whereArgs: [studentId, batchId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<int?> getLastBatchIndex(int studentId, int gradeLevel, String difficulty) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT b.batch_index
      FROM batch_visits bv
      INNER JOIN batches b ON b.id = bv.batch_id
      WHERE bv.student_id = ? AND b.grade_level = ? AND b.difficulty = ?
      ORDER BY bv.first_visit_at DESC
      LIMIT 1
    ''', [studentId, gradeLevel, difficulty]);
    if (maps.isEmpty) return null;
    return maps.first['batch_index'] as int;
  }

  Future<void> saveLessonProgress({
    required int studentId,
    required int batchId,
    required String phase,
    required int index,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawInsert('''
      INSERT INTO lesson_progress
        (student_id, batch_id, current_phase, current_index, last_updated)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(student_id, batch_id) DO UPDATE SET
        current_phase = excluded.current_phase,
        current_index = excluded.current_index,
        last_updated = excluded.last_updated
    ''', [studentId, batchId, phase, index, now]);
  }

  Future<LessonProgress?> getLessonProgress(int studentId, int batchId) async {
    final db = await database;
    final maps = await db.query(
      'lesson_progress',
      where: 'student_id = ? AND batch_id = ?',
      whereArgs: [studentId, batchId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LessonProgress.fromMap(maps.first);
  }

  Future<int> saveQuizAttempt(QuizAttempt attempt) async {
    final db = await database;
    return await db.insert('quiz_attempts', attempt.toMap());
  }

  Future<List<QuizAttempt>> getQuizAttempts(int studentId, int batchId) async {
    final db = await database;
    final maps = await db.query(
      'quiz_attempts',
      where: 'student_id = ? AND batch_id = ?',
      whereArgs: [studentId, batchId],
      orderBy: 'completed_at DESC',
    );
    return maps.map((m) => QuizAttempt.fromMap(m)).toList();
  }

  Future<void> saveQuestionResponse(QuizQuestionResponse response) async {
    final db = await database;
    await db.insert('quiz_question_responses', response.toMap());
  }

  Future<bool> isWordStarred(int studentId, int wordId) async {
    final db = await database;
    final maps = await db.query(
      'starred_words',
      where: 'student_id = ? AND word_id = ?',
      whereArgs: [studentId, wordId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<WordMastery?> getWordMastery(int studentId, int wordId) async {
    final db = await database;
    final maps = await db.query(
      'word_mastery',
      where: 'student_id = ? AND word_id = ?',
      whereArgs: [studentId, wordId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WordMastery.fromMap(maps.first);
  }

  Future<List<WordMastery>> getMasteredWords(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'word_mastery',
      where: 'student_id = ? AND mastered_at IS NOT NULL',
      whereArgs: [studentId],
      orderBy: 'mastered_at DESC',
    );
    return maps.map((m) => WordMastery.fromMap(m)).toList();
  }

  Future<List<int>> getEncounteredWordIds(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'word_encounters',
      columns: ['word_id'],
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return maps.map((m) => m['word_id'] as int).toList();
  }

  Future<void> recordDailyWord({required int studentId, required int wordId}) async {
    final db = await database;
    final now = DateTime.now();
    final dateShown = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await db.insert('daily_word_log', {
        'student_id': studentId,
        'word_id': wordId,
        'date_shown': dateShown,
        'shown_at': now.toIso8601String(),
      });
    } catch (_) {}
  }

  Future<int?> getTodaysWord(int studentId) async {
    final db = await database;
    final now = DateTime.now();
    final dateShown = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'daily_word_log',
      where: 'student_id = ? AND date_shown = ?',
      whereArgs: [studentId, dateShown],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['word_id'] as int;
  }

  Future<List<Map<String, dynamic>>> getAllQuizAttemptsWithBatch(int studentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        qa.id, qa.student_id, qa.batch_id, qa.score, qa.total_questions,
        qa.points_earned, qa.wrong_word_ids_json, qa.completed_at,
        qa.synced_to_cloud,
        b.grade_level, b.difficulty, b.batch_index, b.theme
      FROM quiz_attempts qa
      INNER JOIN batches b ON b.id = qa.batch_id
      WHERE qa.student_id = ?
      ORDER BY qa.completed_at DESC
    ''', [studentId]);
  }

  Future<int> getCompletedLevelCount(int studentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM (
        SELECT DISTINCT b.grade_level, b.difficulty
        FROM quiz_attempts qa
        INNER JOIN batches b ON b.id = qa.batch_id
        WHERE qa.student_id = ?
          AND (qa.score * 1.0 / qa.total_questions) >= 0.70
      )
    ''', [studentId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>> getQuizStatsForStudent(int studentId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(score), 0) as total_correct,
        COALESCE(SUM(total_questions), 0) as total_questions,
        COUNT(*) as attempt_count
      FROM quiz_attempts
      WHERE student_id = ?
    ''', [studentId]);
    final row = rows.first;
    final totalCorrect = (row['total_correct'] as int?) ?? 0;
    final totalQuestions = (row['total_questions'] as int?) ?? 0;
    final attemptCount = (row['attempt_count'] as int?) ?? 0;
    final accuracy = totalQuestions == 0 ? 0.0 : totalCorrect / totalQuestions;
    return {
      'totalCorrect': totalCorrect,
      'totalQuestions': totalQuestions,
      'attemptCount': attemptCount,
      'accuracy': accuracy,
    };
  }

  Future<List<Word>> getWeakWordsFromAttempts(int studentId, {int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'quiz_attempts',
      columns: ['wrong_word_ids_json'],
      where: 'student_id = ? AND wrong_word_ids_json IS NOT NULL AND wrong_word_ids_json != ""',
      whereArgs: [studentId],
      orderBy: 'completed_at DESC',
    );
    final Set<int> uniqueIds = {};
    for (final row in rows) {
      final raw = row['wrong_word_ids_json'] as String?;
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
    final wordRows = await db.query('words', where: 'id IN ($placeholders)', whereArgs: uniqueIds.toList());
    return wordRows.map((m) => Word.fromMap(m)).toList();
  }

  Future<Map<String, Map<String, int>>> getQuestionTypeStats(int studentId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        qq.question_type AS type,
        COUNT(*) AS total,
        SUM(CASE WHEN qqr.is_correct = 1 THEN 1 ELSE 0 END) AS correct
      FROM quiz_question_responses qqr
      INNER JOIN quiz_questions qq ON qq.id = qqr.question_id
      INNER JOIN quiz_attempts qa ON qa.id = qqr.attempt_id
      WHERE qa.student_id = ?
      GROUP BY qq.question_type
    ''', [studentId]);
    final result = <String, Map<String, int>>{};
    for (final r in rows) {
      result[r['type'] as String] = {
        'total': (r['total'] as int?) ?? 0,
        'correct': (r['correct'] as int?) ?? 0,
      };
    }
    return result;
  }

  Future<Map<String, int>> getMasteryBreakdown(int studentId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN mastered_at IS NOT NULL THEN 1 ELSE 0 END) AS mastered,
        SUM(CASE WHEN mastered_at IS NULL AND wrong_count > 0 THEN 1 ELSE 0 END) AS struggling,
        SUM(CASE WHEN mastered_at IS NULL AND wrong_count = 0 AND correct_count > 0 THEN 1 ELSE 0 END) AS learning
      FROM word_mastery
      WHERE student_id = ?
    ''', [studentId]);
    if (rows.isEmpty) return {'mastered': 0, 'struggling': 0, 'learning': 0};
    final r = rows.first;
    return {
      'mastered': (r['mastered'] as int?) ?? 0,
      'struggling': (r['struggling'] as int?) ?? 0,
      'learning': (r['learning'] as int?) ?? 0,
    };
  }

  Future<Set<int>> getStarredWordIds(int studentId) async {
    final db = await database;
    final rows = await db.query(
      'starred_words',
      columns: ['word_id'],
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return rows.map((r) => r['word_id'] as int).toSet();
  }

  Future<Set<int>> getMasteredWordIds(int studentId) async {
    final db = await database;
    final rows = await db.query(
      'word_mastery',
      columns: ['word_id'],
      where: 'student_id = ? AND mastered_at IS NOT NULL',
      whereArgs: [studentId],
    );
    return rows.map((r) => r['word_id'] as int).toSet();
  }

  Future<Set<int>> getWeakWordIds(int studentId) async {
    final weak = await getWeakWordsFromAttempts(studentId);
    return weak.where((w) => w.id != null).map((w) => w.id!).toSet();
  }

  Future<Word?> getOrPickTodaysWord(int studentId, int gradeLevel) async {
    final existingId = await DatabaseService.instance.getTodaysWord(studentId);
    if (existingId != null) return await getWordById(existingId);
    final db = await database;
    final candidates = await db.query('words', where: 'grade_level = ?', whereArgs: [gradeLevel], orderBy: 'text ASC');
    if (candidates.isEmpty) return null;
    final now = DateTime.now();
    final dayOfYear = DateTime(now.year, now.month, now.day).difference(DateTime(now.year, 1, 1)).inDays;
    final seed = studentId * 1000 + dayOfYear;
    final picked = candidates[seed % candidates.length];
    final word = Word.fromMap(picked);
    if (word.id != null) await recordDailyWord(studentId: studentId, wordId: word.id!);
    return word;
  }

  Future<bool> hasPassedDifficulty(int studentId, int gradeLevel, String difficulty) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM quiz_attempts qa
      INNER JOIN batches b ON b.id = qa.batch_id
      WHERE qa.student_id = ?
        AND b.grade_level = ?
        AND b.difficulty = ?
        AND (qa.score * 1.0 / qa.total_questions) >= 0.70
    ''', [studentId, gradeLevel, difficulty]);
    final count = Sqflite.firstIntValue(rows) ?? 0;
    return count > 0;
  }
}