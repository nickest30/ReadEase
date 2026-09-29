import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/word.dart';
import '../models/quiz_result.dart';
import '../models/parent.dart';
import '../models/teacher.dart';
import '../models/class_group.dart';
import '../models/badge.dart';
import '../models/content_models.dart';


class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'readease.db');

    return await openDatabase(
      path,
      version: 9,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        display_name TEXT NOT NULL,
        grade_level INTEGER NOT NULL,
        pin_hash TEXT,
        is_linked INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        total_points INTEGER NOT NULL DEFAULT 0,
        firebase_uid TEXT,
        class_firestore_id TEXT,
        class_name TEXT,
        last_synced_at TEXT,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        image_asset TEXT NOT NULL,
        audio_asset TEXT NOT NULL,
        quiz_choices TEXT NOT NULL,
        correct_answer TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        points_earned INTEGER NOT NULL,
        wrong_word_ids TEXT,
        synced_to_cloud INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE parents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        created_at TEXT NOT NULL,
        firebase_uid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        school_name TEXT NOT NULL,
        firebase_uid TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE class_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER NOT NULL,
        class_name TEXT NOT NULL,
        grade_level INTEGER NOT NULL,
        join_code TEXT UNIQUE NOT NULL,
        firestore_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (teacher_id) REFERENCES teachers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE badges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        badge_name TEXT NOT NULL,
        points_earned INTEGER NOT NULL,
        earned_at TEXT NOT NULL,
        synced_to_cloud INTEGER NOT NULL DEFAULT 0,
        UNIQUE(student_id, grade_level, difficulty),
        FOREIGN KEY (student_id) REFERENCES students (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE class_enrollments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_group_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        enrolled_at TEXT NOT NULL,
        FOREIGN KEY (class_group_id) REFERENCES class_groups (id),
        FOREIGN KEY (student_id) REFERENCES students (id)
      )
    ''');



    // ============================================================
    // Content Pipeline Tables
    // ============================================================

    // batches — small groups of 3-5 words
    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        batch_index INTEGER NOT NULL,
        theme TEXT NOT NULL,
        cultural_elements_json TEXT
      )
    ''');

    // opening_frames — Grade 1
    await db.execute('''
      CREATE TABLE opening_frames (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        visual_asset TEXT NOT NULL,
        audio_asset TEXT NOT NULL,
        display_text TEXT NOT NULL,
        trigger_type TEXT NOT NULL DEFAULT 'first_visit_only'
      )
    ''');

    // story_frames — Grade 2+
    await db.execute('''
      CREATE TABLE story_frames (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        frame_index INTEGER NOT NULL,
        visual_asset TEXT NOT NULL,
        audio_asset TEXT NOT NULL,
        display_text TEXT NOT NULL,
        word_introduced_id INTEGER
      )
    ''');

    // quiz_questions — separate from words
    await db.execute('''
      CREATE TABLE quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        question_stem TEXT NOT NULL,
        question_type TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        distractors_json TEXT NOT NULL,
        show_image INTEGER DEFAULT 1,
        order_index INTEGER NOT NULL
      )
    ''');

    // quiz_config — per-level quiz rules
    await db.execute('''
      CREATE TABLE quiz_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        quiz_size INTEGER NOT NULL,
        buffer_size INTEGER NOT NULL DEFAULT 0,
        randomized INTEGER NOT NULL DEFAULT 0,
        passing_threshold INTEGER DEFAULT 70
      )
    ''');

    // passages — G3+
    await db.execute('''
      CREATE TABLE passages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        full_text TEXT NOT NULL,
        word_count INTEGER NOT NULL,
        phil_iri_target_grade INTEGER NOT NULL,
        phil_iri_readability_score REAL,
        phil_iri_readability_tool TEXT,
        cultural_elements_json TEXT
      )
    ''');

    // passage_sentences
    await db.execute('''
      CREATE TABLE passage_sentences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passage_id INTEGER NOT NULL,
        sentence_index INTEGER NOT NULL,
        text TEXT NOT NULL,
        audio_file TEXT NOT NULL
      )
    ''');

    // passage_words
    await db.execute('''
      CREATE TABLE passage_words (
        passage_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        is_tone_word INTEGER DEFAULT 0,
        PRIMARY KEY (passage_id, word_id)
      )
    ''');

    // word_encounters — Pokédex "seen"
    await db.execute('''
      CREATE TABLE word_encounters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        first_seen_at TEXT NOT NULL,
        times_seen INTEGER DEFAULT 1,
        UNIQUE(student_id, word_id)
      )
    ''');

    // word_mastery — Pokédex "mastered"
    await db.execute('''
      CREATE TABLE word_mastery (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        correct_count INTEGER DEFAULT 0,
        wrong_count INTEGER DEFAULT 0,
        mastered_at TEXT,
        UNIQUE(student_id, word_id)
      )
    ''');

    // starred_words
    await db.execute('''
      CREATE TABLE starred_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        starred_at TEXT NOT NULL,
        UNIQUE(student_id, word_id)
      )
    ''');

    // batch_visits — for Yse Opening Frame
    await db.execute('''
      CREATE TABLE batch_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        first_visit_at TEXT NOT NULL,
        UNIQUE(student_id, batch_id)
      )
    ''');

    // lesson_progress — for resume
    await db.execute('''
      CREATE TABLE lesson_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        current_phase TEXT NOT NULL,
        current_index INTEGER DEFAULT 0,
        last_updated TEXT NOT NULL,
        UNIQUE(student_id, batch_id)
      )
    ''');

    // quiz_attempts — replaces quiz_results for new flow
    await db.execute('''
      CREATE TABLE quiz_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        points_earned INTEGER NOT NULL,
        wrong_word_ids_json TEXT,
        completed_at TEXT NOT NULL,
        synced_to_cloud INTEGER DEFAULT 0
      )
    ''');

    // quiz_question_responses — analytics
    await db.execute('''
      CREATE TABLE quiz_question_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        attempt_id INTEGER NOT NULL,
        question_id INTEGER NOT NULL,
        selected_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        response_time_ms INTEGER
      )
    ''');

    // daily_word_log — Word of the Day
    await db.execute('''
      CREATE TABLE daily_word_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        date_shown TEXT NOT NULL,
        shown_at TEXT NOT NULL,
        UNIQUE(student_id, date_shown)
      )
    ''');

    // content_versions — track JSON imports
    await db.execute('''
      CREATE TABLE content_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        version TEXT NOT NULL,
        imported_at TEXT NOT NULL
      )
    ''');




  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE quiz_results ADD COLUMN wrong_word_ids TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE students ADD COLUMN class_firestore_id TEXT',
      );
      await db.execute(
        'ALTER TABLE students ADD COLUMN class_name TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE students ADD COLUMN last_synced_at TEXT',
      );
      await db.execute(
        'ALTER TABLE students ADD COLUMN pending_sync INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      // Safety: ensure wrong_word_ids exists
      try {
        await db.execute(
          'ALTER TABLE quiz_results ADD COLUMN wrong_word_ids TEXT',
        );
      } catch (_) {
        // Column already exists — ignore
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE class_groups ADD COLUMN firestore_id TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE quiz_results ADD COLUMN synced_to_cloud INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Column may already exist on fresh installs
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS badges (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            grade_level INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            badge_name TEXT NOT NULL,
            points_earned INTEGER NOT NULL,
            earned_at TEXT NOT NULL,
            synced_to_cloud INTEGER NOT NULL DEFAULT 0,
            UNIQUE(student_id, grade_level, difficulty),
            FOREIGN KEY (student_id) REFERENCES students (id)
          )
        ''');
      } catch (_) {}
    }

    if (oldVersion < 9) {
    try {
      await db.execute('ALTER TABLE words ADD COLUMN batch_id INTEGER');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE words ADD COLUMN category TEXT DEFAULT 'general'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE words ADD COLUMN lesson_cue TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE words ADD COLUMN definition TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE words ADD COLUMN sample_sentence TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE words ADD COLUMN source TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE words ADD COLUMN sensitivity_reviewed INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE words ADD COLUMN sensitivity_notes TEXT');
    } catch (_) {}

    // Create the new content tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        batch_index INTEGER NOT NULL,
        theme TEXT NOT NULL,
        cultural_elements_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS opening_frames (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        visual_asset TEXT NOT NULL,
        audio_asset TEXT NOT NULL,
        display_text TEXT NOT NULL,
        trigger_type TEXT NOT NULL DEFAULT 'first_visit_only'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS story_frames (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        frame_index INTEGER NOT NULL,
        visual_asset TEXT NOT NULL,
        audio_asset TEXT NOT NULL,
        display_text TEXT NOT NULL,
        word_introduced_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        question_stem TEXT NOT NULL,
        question_type TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        distractors_json TEXT NOT NULL,
        show_image INTEGER DEFAULT 1,
        order_index INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        quiz_size INTEGER NOT NULL,
        buffer_size INTEGER NOT NULL DEFAULT 0,
        randomized INTEGER NOT NULL DEFAULT 0,
        passing_threshold INTEGER DEFAULT 70
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS passages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        full_text TEXT NOT NULL,
        word_count INTEGER NOT NULL,
        phil_iri_target_grade INTEGER NOT NULL,
        phil_iri_readability_score REAL,
        phil_iri_readability_tool TEXT,
        cultural_elements_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS passage_sentences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passage_id INTEGER NOT NULL,
        sentence_index INTEGER NOT NULL,
        text TEXT NOT NULL,
        audio_file TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS passage_words (
        passage_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        is_tone_word INTEGER DEFAULT 0,
        PRIMARY KEY (passage_id, word_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_encounters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        first_seen_at TEXT NOT NULL,
        times_seen INTEGER DEFAULT 1,
        UNIQUE(student_id, word_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_mastery (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        correct_count INTEGER DEFAULT 0,
        wrong_count INTEGER DEFAULT 0,
        mastered_at TEXT,
        UNIQUE(student_id, word_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS starred_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        starred_at TEXT NOT NULL,
        UNIQUE(student_id, word_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS batch_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        first_visit_at TEXT NOT NULL,
        UNIQUE(student_id, batch_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        current_phase TEXT NOT NULL,
        current_index INTEGER DEFAULT 0,
        last_updated TEXT NOT NULL,
        UNIQUE(student_id, batch_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        points_earned INTEGER NOT NULL,
        wrong_word_ids_json TEXT,
        completed_at TEXT NOT NULL,
        synced_to_cloud INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_question_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        attempt_id INTEGER NOT NULL,
        question_id INTEGER NOT NULL,
        selected_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        response_time_ms INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_word_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        date_shown TEXT NOT NULL,
        shown_at TEXT NOT NULL,
        UNIQUE(student_id, date_shown)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        version TEXT NOT NULL,
        imported_at TEXT NOT NULL
      )
    ''');
  }



  }

  // ---------- Student methods ----------

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
      'students',
      {'display_name': displayName},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<bool> updateStudentUsername(int studentId, String username) async {
    final db = await database;
    final rows = await db.update(
      'students',
      {'username': username},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }

  Future<bool> updateStudentFirebaseUid(int studentId, String firebaseUid) async {
    final db = await database;
    final rows = await db.update(
      'students',
      {'firebase_uid': firebaseUid},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }


  Future<int> computePointsDelta({
    required int studentId,
    required int gradeLevel,
    required String difficulty,
    required int newScore,
    int pointsPerCorrect = 5,
  }) async {
    final db = await database;

    // Find best previous score for this exact grade + difficulty
    final maps = await db.query(
      'quiz_results',
      columns: ['score'],
      where: 'student_id = ? AND grade_level = ? AND difficulty = ?',
      whereArgs: [studentId, gradeLevel, difficulty],
      orderBy: 'score DESC',
      limit: 1,
    );

    final int previousBest = maps.isEmpty
        ? 0
        : (maps.first['score'] as int);

    final int newPoints = newScore * pointsPerCorrect;
    final int previousBestPoints = previousBest * pointsPerCorrect;

    final int delta = newPoints - previousBestPoints;

    // Only positive improvements count
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

  /// Mark a student as needing cloud sync.
  Future<bool> markStudentPendingSync(int studentId) async {
    final db = await database;
    final rows = await db.update(
      'students',
      {'pending_sync': 1},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }

  /// Mark a student as synced (with current timestamp).
  Future<bool> markStudentSynced(int studentId) async {
    final db = await database;
    final rows = await db.update(
      'students',
      {
        'pending_sync': 0,
        'last_synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }

  /// Get all students that need to be synced.
  Future<List<Student>> getPendingSyncStudents() async {
    final db = await database;
    final maps = await db.query(
      'students',
      where: 'pending_sync = 1',
    );
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
        'parent_id': parentFirebaseUid.hashCode, // placeholder integer
        'is_linked': isLinked ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
    return rows > 0;
  }

  // ---------- Word methods ----------

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

  // ---------- QuizResult methods ----------

  Future<int> insertQuizResult(QuizResult result) async {
    final db = await database;
    return await db.insert('quiz_results', result.toMap());
  }

  Future<List<QuizResult>> getResultsForStudent(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'quiz_results', where: 'student_id = ?', whereArgs: [studentId],
    );
    return maps.map((map) => QuizResult.fromMap(map)).toList();
  }

  Future<bool> hasPassedDifficulty(int studentId, int gradeLevel, String difficulty) async {
    final db = await database;
    final maps = await db.query(
      'quiz_results',
      where: 'student_id = ? AND grade_level = ? AND difficulty = ? AND (score * 1.0 / total_questions) >= 0.70',
      whereArgs: [studentId, gradeLevel, difficulty],
    );
    return maps.isNotEmpty;
  }

  /// Mark a quiz result as synced to cloud.
  Future<bool> markResultSynced(int resultId) async {
    final db = await database;
    final rows = await db.update(
      'quiz_results',
      {'synced_to_cloud': 1},
      where: 'id = ?',
      whereArgs: [resultId],
    );
    return rows > 0;
  }

  /// Get all unsynced quiz results for a student.
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

  // ---------- Parent methods ----------

  Future<int> insertParent(Parent parent) async {
    final db = await database;
    return await db.insert('parents', parent.toMap());
  }

  Future<Parent?> getParentByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'parents', where: 'username = ?', whereArgs: [username],
    );
    if (maps.isEmpty) return null;
    return Parent.fromMap(maps.first);
  }

  Future<bool> updateParentFirebaseUid(int parentId, String firebaseUid) async {
    final db = await database;
    final rows = await db.update(
      'parents',
      {'firebase_uid': firebaseUid},
      where: 'id = ?',
      whereArgs: [parentId],
    );
    return rows > 0;
  }

  Future<Parent?> getParentById(int id) async {
    final db = await database;
    final maps = await db.query(
      'parents', where: 'id = ?', whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Parent.fromMap(maps.first);
  }

  Future<List<Student>> getChildrenOfParent(int parentId) async {
    final db = await database;
    final maps = await db.query(
      'students',
      where: 'parent_id = ? AND is_linked = 1',
      whereArgs: [parentId],
    );
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  Future<int> insertLinkedStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  Future<int> deleteStudent(int studentId) async {
    final db = await database;
    return await db.delete(
      'students', where: 'id = ?', whereArgs: [studentId],
    );
  }

  // ---------- Teacher methods ----------

  Future<int> insertTeacher(Teacher teacher) async {
    final db = await database;
    return await db.insert('teachers', teacher.toMap());
  }

  Future<Teacher?> getTeacherByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'teachers', where: 'username = ?', whereArgs: [username],
    );
    if (maps.isEmpty) return null;
    return Teacher.fromMap(maps.first);
  }

  Future<bool> updateTeacherFirebaseUid(int teacherId, String firebaseUid) async {
    final db = await database;
    final rows = await db.update(
      'teachers',
      {'firebase_uid': firebaseUid},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
    return rows > 0;
  }

  Future<Teacher?> getTeacherById(int id) async {
    final db = await database;
    final maps = await db.query(
      'teachers', where: 'id = ?', whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Teacher.fromMap(maps.first);
  }

  // ---------- ClassGroup methods ----------

  Future<int> insertClassGroup(ClassGroup group) async {
    final db = await database;
    return await db.insert('class_groups', group.toMap());
  }

  Future<List<ClassGroup>> getClassGroupsByTeacher(int teacherId) async {
    final db = await database;
    final maps = await db.query(
      'class_groups',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ClassGroup.fromMap(map)).toList();
  }

  Future<ClassGroup?> getClassGroupByJoinCode(String joinCode) async {
    final db = await database;
    final maps = await db.query(
      'class_groups',
      where: 'join_code = ?',
      whereArgs: [joinCode],
    );
    if (maps.isEmpty) return null;
    return ClassGroup.fromMap(maps.first);
  }

  Future<ClassGroup?> getClassGroupById(int id) async {
    final db = await database;
    final maps = await db.query(
      'class_groups', where: 'id = ?', whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ClassGroup.fromMap(maps.first);
  }

  Future<bool> updateClassGroupFirestoreId(
    int localId,
    String firestoreId,
  ) async {
    final db = await database;
    final rows = await db.update(
      'class_groups',
      {'firestore_id': firestoreId},
      where: 'id = ?',
      whereArgs: [localId],
    );
    return rows > 0;
  }

  // ---------- Enrollment methods ----------

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
    final maps = await db.query(
      'class_enrollments',
      where: 'class_group_id = ? AND student_id = ?',
      whereArgs: [classGroupId, studentId],
    );
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


  // ─────────────────────────────────────────────────────────
  // BADGE METHODS
  // ─────────────────────────────────────────────────────────

  /// Award a badge. Returns true if a new badge was created.
  Future<bool> awardBadge(AchievementBadge badge) async {
    final db = await database;
    try {
      final id = await db.insert(
        'badges',
        badge.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return id > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get all badges earned by a student.
  Future<List<AchievementBadge>> getBadgesForStudent(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'badges',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'earned_at DESC',
    );
    return maps.map((m) => AchievementBadge.fromMap(m)).toList();
  }

  /// Get unsynced badges.
  Future<List<AchievementBadge>> getPendingSyncBadges(int studentId) async {
    final db = await database;
    final maps = await db.query(
      'badges',
      where: 'student_id = ? AND synced_to_cloud = 0',
      whereArgs: [studentId],
    );
    return maps.map((m) => AchievementBadge.fromMap(m)).toList();
  }

  /// Mark a badge as synced.
  Future<bool> markBadgeSynced(int badgeId) async {
    final db = await database;
    final rows = await db.update(
      'badges',
      {'synced_to_cloud': 1},
      where: 'id = ?',
      whereArgs: [badgeId],
    );
    return rows > 0;
  }


  // ============================================================
  // CONTENT QUERIES
  // ============================================================

  /// Get all words in a specific batch (ordered).
  Future<List<Word>> getWordsInBatch(int batchId) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'batch_id = ?',
      whereArgs: [batchId],
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  /// Get the first batch for a (grade, difficulty) combination.
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

  /// Get all batches for a (grade, difficulty).
  Future<List<LessonBatch>> getBatchesForLevel(
      int gradeLevel, String difficulty) async {
    final db = await database;
    final maps = await db.query(
      'batches',
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
      orderBy: 'batch_index ASC',
    );
    return maps.map((m) => LessonBatch.fromMap(m)).toList();
  }

  /// Get the quiz config for a level.
  Future<QuizConfig?> getQuizConfig(
      int gradeLevel, String difficulty) async {
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

  /// Get all quiz questions for a batch.
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

  /// Get the opening frame for Grade 1 level.
  Future<OpeningFrame?> getOpeningFrame(
      int gradeLevel, String difficulty) async {
    final db = await database;
    final maps = await db.query(
      'opening_frames',
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return OpeningFrame.fromMap(maps.first);
  }

  /// Get story frames for a (grade, difficulty).
  Future<List<StoryFrame>> getStoryFrames(
      int gradeLevel, String difficulty) async {
    final db = await database;
    final maps = await db.query(
      'story_frames',
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
      orderBy: 'frame_index ASC',
    );
    return maps.map((m) => StoryFrame.fromMap(m)).toList();
  }

  /// Get the passage for a batch (G3+).
  Future<Passage?> getPassageForBatch(int batchId) async {
    final db = await database;
    final maps = await db.query(
      'passages',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Passage.fromMap(maps.first);
  }

  /// Get all sentences for a passage.
  Future<List<PassageSentence>> getSentencesForPassage(
      int passageId) async {
    final db = await database;
    final maps = await db.query(
      'passage_sentences',
      where: 'passage_id = ?',
      whereArgs: [passageId],
      orderBy: 'sentence_index ASC',
    );
    return maps.map((m) => PassageSentence.fromMap(m)).toList();
  }

  // ============================================================
  // M5.1 — PROGRESS METHODS
  // ============================================================

  /// Record a word encounter (Pokédex "seen").
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

  /// Update word mastery after a quiz answer.
  /// Returns true if the word just became mastered.
  Future<bool> updateWordMastery({
    required int studentId,
    required int wordId,
    required bool correct,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Fetch existing
    final maps = await db.query(
      'word_mastery',
      where: 'student_id = ? AND word_id = ?',
      whereArgs: [studentId, wordId],
      limit: 1,
    );

    if (maps.isEmpty) {
      // First attempt
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

    // Update existing
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
      {
        'correct_count': newCorrect,
        'wrong_count': newWrong,
        'mastered_at': newMasteredAt,
      },
      where: 'student_id = ? AND word_id = ?',
      whereArgs: [studentId, wordId],
    );
    return justMastered;
  }

  /// Star a word.
  Future<void> starWord(int studentId, int wordId) async {
    final db = await database;
    await db.insert(
      'starred_words',
      {
        'student_id': studentId,
        'word_id': wordId,
        'starred_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Unstar a word.
  Future<void> unstarWord(int studentId, int wordId) async {
    final db = await database;
    await db.delete(
      'starred_words',
      where: 'student_id = ? AND word_id = ?',
      whereArgs: [studentId, wordId],
    );
  }

  /// Get all starred words for a student.
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

  /// Record a batch visit (Yse Opening Frame tracking).
  Future<void> recordBatchVisit(int studentId, int batchId) async {
    final db = await database;
    await db.insert(
      'batch_visits',
      {
        'student_id': studentId,
        'batch_id': batchId,
        'first_visit_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Check if a batch has been visited before.
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

  /// Get the last visited batch index for a level (for resume).
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

  /// Save lesson progress (for resume).
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

  /// Get lesson progress for a batch.
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

  /// Save a quiz attempt.
  Future<int> saveQuizAttempt(QuizAttempt attempt) async {
    final db = await database;
    return await db.insert('quiz_attempts', attempt.toMap());
  }

  /// Get all quiz attempts for a student in a batch.
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

  /// Save a per-question response.
  Future<void> saveQuestionResponse(QuizQuestionResponse response) async {
    final db = await database;
    await db.insert('quiz_question_responses', response.toMap());
  }

  /// Check if a word is starred.
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

  /// Get word mastery for a specific word.
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

  /// Get all mastered words for a student.
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

  /// Get all encountered word IDs for a student.
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

  /// Get content version for a grade (returns null if not imported).
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

  /// Save content version.
  Future<void> saveContentVersion(ContentVersion version) async {
    final db = await database;
    await db.insert('content_versions', version.toMap());
  }

  /// Delete all content for a grade (for re-import).
  Future<void> clearContentForGrade(int gradeLevel) async {
    final db = await database;
    await db.delete('words',
        where: 'grade_level = ?', whereArgs: [gradeLevel]);
    await db.delete('batches',
        where: 'grade_level = ?', whereArgs: [gradeLevel]);
    await db.delete('opening_frames',
        where: 'grade_level = ?', whereArgs: [gradeLevel]);
    await db.delete('story_frames',
        where: 'grade_level = ?', whereArgs: [gradeLevel]);
    await db.delete('quiz_config',
        where: 'grade_level = ?', whereArgs: [gradeLevel]);
    await db.delete('content_versions',
        where: 'grade_level = ?', whereArgs: [gradeLevel]);
  }

  /// Record a Word of the Day shown to student.
  Future<void> recordDailyWord({
    required int studentId,
    required int wordId,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final dateShown =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await db.insert('daily_word_log', {
        'student_id': studentId,
        'word_id': wordId,
        'date_shown': dateShown,
        'shown_at': now.toIso8601String(),
      });
    } catch (_) {
      // Already shown today
    }
  }

  /// Get today's Word of the Day word ID for a student.
  Future<int?> getTodaysWord(int studentId) async {
    final db = await database;
    final now = DateTime.now();
    final dateShown =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'daily_word_log',
      where: 'student_id = ? AND date_shown = ?',
      whereArgs: [studentId, dateShown],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['word_id'] as int;
  }

  // ============================================================
  // M5.1 — CONTENT INSERT METHODS (used by importer)
  // ============================================================

  Future<int> insertBatch(LessonBatch batch) async {
    final db = await database;
    return await db.insert('batches', batch.toMap());
  }

  Future<int> insertOpeningFrame(OpeningFrame frame) async {
    final db = await database;
    return await db.insert('opening_frames', frame.toMap());
  }

  Future<int> insertQuizConfig(QuizConfig config) async {
    final db = await database;
    return await db.insert('quiz_config', config.toMap());
  }

  Future<int> insertQuizQuestion(QuizQuestion question) async {
    final db = await database;
    return await db.insert('quiz_questions', question.toMap());
  }

}