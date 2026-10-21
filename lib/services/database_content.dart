part of 'database_service.dart';

extension DatabaseContent on DatabaseService {
  Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('words', word.toMap());
  }

  Future<List<Word>> getWords(int gradeLevel, String difficulty) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
    );
    return maps.map((map) => Word.fromMap(map)).toList();
  }

  Future<int> getWordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM words');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> upsertWordByNaturalKey(Word word) async {
    final db = await database;
    final existing = await db.query(
      'words',
      where: 'grade_level = ? AND difficulty = ? AND text = ?',
      whereArgs: [word.gradeLevel, word.difficulty, word.text],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      final updated = word.toMap()..['id'] = id;
      await db.update('words', updated, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    return await db.insert('words', word.toMap());
  }

  Future<int> upsertBatchByNaturalKey(LessonBatch batch) async {
    final db = await database;
    final existing = await db.query(
      'batches',
      where: 'grade_level = ? AND difficulty = ? AND batch_index = ?',
      whereArgs: [batch.gradeLevel, batch.difficulty, batch.batchIndex],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      final updated = batch.toMap()..['id'] = id;
      await db.update('batches', updated, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    return await db.insert('batches', batch.toMap());
  }

  Future<void> deleteQuizQuestionsForWord(int wordId) async {
    final db = await database;
    await db.delete('quiz_questions', where: 'word_id = ?', whereArgs: [wordId]);
  }

  Future<List<Word>> getWordsInBatch(int batchId) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'batch_id = ?',
      whereArgs: [batchId],
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<List<Word>> getSampledWordsForBatch(int batchId) async {
    final db = await database;
    final batchRows = await db.query(
      'batches',
      where: 'id = ?',
      whereArgs: [batchId],
      limit: 1,
    );
    if (batchRows.isEmpty) return [];

    final gradeLevel = batchRows.first['grade_level'] as int;
    final difficulty = batchRows.first['difficulty'] as String;

    final wordRows = await db.query(
      'words',
      where: 'batch_id = ?',
      whereArgs: [batchId],
    );
    if (wordRows.isEmpty) return [];

    final allWords = wordRows.map((m) => Word.fromMap(m)).toList();

    final cfgRows = await db.query(
      'quiz_config',
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
      limit: 1,
    );
    if (cfgRows.isEmpty) return allWords;

    final randomized = ((cfgRows.first['randomized'] as int?) ?? 0) == 1;
    final quizSize = (cfgRows.first['quiz_size'] as int?) ?? allWords.length;

    if (!randomized || allWords.length <= quizSize) return allWords;

    final shuffled = List<Word>.from(allWords)..shuffle();
    return shuffled.take(quizSize).toList();
  }

  Future<LessonBatch?> getFirstBatch(int gradeLevel, String difficulty) async {
    final db = await database;
    final maps = await db.query(
      'batches',
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
      orderBy: 'batch_index ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LessonBatch.fromMap(maps.first);
  }

  Future<List<LessonBatch>> getBatchesForLevel(
    int gradeLevel,
    String difficulty,
  ) async {
    final db = await database;
    final maps = await db.query(
      'batches',
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
      orderBy: 'batch_index ASC',
    );
    return maps.map((m) => LessonBatch.fromMap(m)).toList();
  }

  Future<QuizConfig?> getQuizConfig(int gradeLevel, String difficulty) async {
    final db = await database;
    final maps = await db.query(
      'quiz_config',
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return QuizConfig.fromMap(maps.first);
  }

  Future<List<QuizQuestion>> getQuestionsForBatch(int batchId) async {
    final db = await database;
    final maps = await db.query(
      'quiz_questions',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'order_index ASC',
    );
    return maps.map((m) => QuizQuestion.fromMap(m)).toList();
  }

  Future<Passage?> getPassageForBatch(int batchId) async {
    final db = await database;
    final batchRows = await db.query(
      'batches',
      columns: ['passage_id'],
      where: 'id = ?',
      whereArgs: [batchId],
      limit: 1,
    );
    if (batchRows.isEmpty) return null;
    final passageKey = batchRows.first['passage_id'] as String?;
    if (passageKey == null || passageKey.isEmpty) return null;
    return getPassageByKey(passageKey);
  }

  Future<int> insertPassage(Passage passage) async {
    final db = await database;
    return await db.insert('passages', passage.toMap());
  }

  Future<int> insertPassageSentence(PassageSentence sentence) async {
    final db = await database;
    return await db.insert('passage_sentences', sentence.toMap());
  }

  Future<int> insertPassageQuestion(PassageQuestion q) async {
    final db = await database;
    return await db.insert('passage_questions', q.toMap());
  }

  Future<Passage?> getPassageByKey(String passageKey) async {
    final db = await database;
    final rows = await db.query(
      'passages',
      where: 'passage_key = ?',
      whereArgs: [passageKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Passage.fromMap(rows.first);
  }

  Future<List<PassageSentence>> getSentencesForPassage(int passageId) async {
    final db = await database;
    final rows = await db.query(
      'passage_sentences',
      where: 'passage_id = ?',
      whereArgs: [passageId],
      orderBy: 'sentence_index ASC',
    );
    return rows.map((m) => PassageSentence.fromMap(m)).toList();
  }

  Future<List<PassageQuestion>> getQuestionsForPassage(int passageId) async {
    final db = await database;
    final rows = await db.query(
      'passage_questions',
      where: 'passage_id = ?',
      whereArgs: [passageId],
      orderBy: 'order_index ASC',
    );
    return rows.map((m) => PassageQuestion.fromMap(m)).toList();
  }

  Future<void> clearPassagesForGrade(int gradeLevel) async {
    final db = await database;
    final rows = await db.query(
      'passages',
      columns: ['id'],
      where: 'grade_level = ?',
      whereArgs: [gradeLevel],
    );
    for (final r in rows) {
      final id = r['id'] as int;
      await db.delete(
        'passage_sentences',
        where: 'passage_id = ?',
        whereArgs: [id],
      );
      await db.delete(
        'passage_questions',
        where: 'passage_id = ?',
        whereArgs: [id],
      );
    }
    await db.delete('passages', where: 'grade_level = ?', whereArgs: [gradeLevel]);
  }

  Future<int> insertBatch(LessonBatch batch) async {
    final db = await database;
    return await db.insert('batches', batch.toMap());
  }

  Future<int> insertQuizConfig(QuizConfig config) async {
    final db = await database;
    return await db.insert('quiz_config', config.toMap());
  }

  Future<int> insertQuizQuestion(QuizQuestion question) async {
    final db = await database;
    return await db.insert('quiz_questions', question.toMap());
  }

  Future<ContentVersion?> getContentVersion(int gradeLevel) async {
    final db = await database;
    final maps = await db.query(
      'content_versions',
      where: 'grade_level = ?',
      whereArgs: [gradeLevel],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ContentVersion.fromMap(maps.first);
  }

  Future<void> saveContentVersion(ContentVersion version) async {
    final db = await database;
    await db.insert('content_versions', version.toMap());
  }

  Future<void> clearContentForGrade(int gradeLevel) async {
    final db = await database;
    // Note: opening_frames and story_frames tables were dropped in DB v21.
    // Do not add them back here.
    await db.delete('quiz_config', where: 'grade_level = ?', whereArgs: [gradeLevel]);
    await db.delete('content_versions', where: 'grade_level = ?', whereArgs: [gradeLevel]);
  }

  Future<List<Word>> getAllWords({int? gradeLevel}) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: gradeLevel != null ? 'grade_level = ?' : null,
      whereArgs: gradeLevel != null ? [gradeLevel] : null,
      orderBy: 'text COLLATE NOCASE ASC, grade_level ASC',
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<Word?> getWordById(int wordId) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  Future<Word?> getWordByText(int gradeLevel, String text) async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT * FROM words '
      'WHERE grade_level = ? AND LOWER(text) = LOWER(?) '
      'LIMIT 1',
      [gradeLevel, text.trim()],
    );
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  Future<LessonIntro?> getLessonIntro(int grade, String difficulty) async {
    final db = await database;
    final maps = await db.query(
      'lesson_intros',
      where: 'grade = ? AND difficulty = ?',
      whereArgs: [grade, difficulty],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LessonIntro.fromMap(maps.first);
  }

  Future<GameIntro?> getGameIntro(String gameType) async {
    final db = await database;
    final maps = await db.query(
      'game_intros',
      where: 'game_type = ?',
      whereArgs: [gameType],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return GameIntro.fromMap(maps.first);
  }

  Future<int> upsertLessonIntro(LessonIntro intro) async {
    final db = await database;
    return await db.insert(
      'lesson_intros',
      intro.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> upsertGameIntro(GameIntro intro) async {
    final db = await database;
    return await db.insert(
      'game_intros',
      intro.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearIntrosForGrade(int grade) async {
    final db = await database;
    await db.delete('lesson_intros', where: 'grade = ?', whereArgs: [grade]);
  }

  Future<LessonBatch?> getBatchById(int batchId) async {
    final db = await database;
    final maps = await db.query(
      'batches',
      where: 'id = ?',
      whereArgs: [batchId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LessonBatch.fromMap(maps.first);
  }
}