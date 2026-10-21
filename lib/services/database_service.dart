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

part 'database_students.dart';
part 'database_content.dart';
part 'database_progress.dart';
part 'database_roles.dart';
part 'database_sync.dart';

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
      version: 22,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT,                        
        display_name TEXT NOT NULL,
        grade_level INTEGER NOT NULL,
        pin_hash TEXT,
        is_linked INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        parent_firebase_uid TEXT,                  
        total_points INTEGER NOT NULL DEFAULT 0,
        recovery_email TEXT,                       
        recovery_email_verified INTEGER DEFAULT 0, 
        firebase_uid TEXT,
        class_firestore_id TEXT,
        class_name TEXT,
        last_synced_at TEXT,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        avatar_index INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        batch_id INTEGER,
        category TEXT DEFAULT 'general',
        image_asset TEXT NOT NULL,
        audio_asset TEXT NOT NULL,
        lesson_cue_audio TEXT,
        lesson_cue TEXT DEFAULT '',
        definition TEXT DEFAULT '',
        sample_sentence TEXT DEFAULT '',
        sample_sentence_audio TEXT,
        source TEXT DEFAULT '',
        sensitivity_reviewed INTEGER DEFAULT 0,
        sensitivity_notes TEXT,
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
        email_verified INTEGER DEFAULT 0,          
        phone_number TEXT,                         
        phone_verified INTEGER DEFAULT 0,          
        phone_verified_at TEXT,                    
        backup_code_hash TEXT,                     
        backup_code_used INTEGER DEFAULT 0,        
        created_at TEXT NOT NULL,
        firebase_uid TEXT,
        last_synced_at TEXT,                       
        pending_sync INTEGER DEFAULT 0             
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
        email_verified INTEGER DEFAULT 0,          
        phone_number TEXT,                         
        phone_verified INTEGER DEFAULT 0,          
        phone_verified_at TEXT,                    
        backup_code_hash TEXT,                     
        backup_code_used INTEGER DEFAULT 0,        
        firebase_uid TEXT,
        created_at TEXT NOT NULL,
        last_synced_at TEXT,                       
        pending_sync INTEGER DEFAULT 0             
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

    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        batch_index INTEGER NOT NULL,
        theme TEXT NOT NULL,
        cultural_elements_json TEXT,
        game_type TEXT,
        passage_id TEXT
      )
    ''');

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

    await db.execute('''
      CREATE TABLE starred_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        starred_at TEXT NOT NULL,
        UNIQUE(student_id, word_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE batch_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        first_visit_at TEXT NOT NULL,
        UNIQUE(student_id, batch_id)
      )
    ''');

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

    await db.execute('''
      CREATE TABLE content_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_level INTEGER NOT NULL,
        version TEXT NOT NULL,
        imported_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE login_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        identifier TEXT NOT NULL,
        attempt_at TEXT NOT NULL,
        success INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pin_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_local_id INTEGER NOT NULL,
        attempt_at TEXT NOT NULL,
        success INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        firebase_uid TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at TEXT,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE passage_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passage_id INTEGER NOT NULL,
        stem TEXT NOT NULL,
        question_type TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        distractors_json TEXT NOT NULL,
        show_image INTEGER DEFAULT 0,
        order_index INTEGER NOT NULL,
        stem_audio TEXT,
        FOREIGN KEY (passage_id) REFERENCES passages (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE lesson_intros (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        header TEXT NOT NULL,
        body TEXT NOT NULL,
        button_label TEXT NOT NULL,
        pose_asset TEXT NOT NULL,
        audio_asset TEXT NOT NULL,
        UNIQUE(grade, difficulty)
      )
    ''');

    await db.execute('''
      CREATE TABLE game_intros (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_type TEXT NOT NULL UNIQUE,
        header TEXT NOT NULL,
        body TEXT NOT NULL,
        button_label TEXT NOT NULL,
        pose_asset TEXT NOT NULL,
        audio_asset TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE passages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passage_key TEXT NOT NULL UNIQUE,
        grade_level INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        title TEXT NOT NULL,
        illustration TEXT NOT NULL,
        word_count INTEGER NOT NULL,
        tappable_words_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE passage_sentences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passage_id INTEGER NOT NULL,
        sentence_index INTEGER NOT NULL,
        text TEXT NOT NULL,
        audio TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE quiz_results ADD COLUMN wrong_word_ids TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE students ADD COLUMN class_firestore_id TEXT');
      await db.execute('ALTER TABLE students ADD COLUMN class_name TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE students ADD COLUMN last_synced_at TEXT');
      await db.execute('ALTER TABLE students ADD COLUMN pending_sync INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE quiz_results ADD COLUMN wrong_word_ids TEXT'); } catch (_) {}
    }
    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE class_groups ADD COLUMN firestore_id TEXT'); } catch (_) {}
    }
    if (oldVersion < 7) {
      try { await db.execute('ALTER TABLE quiz_results ADD COLUMN synced_to_cloud INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
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
      try { await db.execute('ALTER TABLE words ADD COLUMN batch_id INTEGER'); } catch (_) {}
      try { await db.execute("ALTER TABLE words ADD COLUMN category TEXT DEFAULT 'general'"); } catch (_) {}
      try { await db.execute("ALTER TABLE words ADD COLUMN lesson_cue TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE words ADD COLUMN definition TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE words ADD COLUMN sample_sentence TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE words ADD COLUMN source TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute('ALTER TABLE words ADD COLUMN sensitivity_reviewed INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE words ADD COLUMN sensitivity_notes TEXT'); } catch (_) {}

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
      await db.execute('''
        CREATE TABLE lesson_intros (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          grade INTEGER NOT NULL,
          difficulty TEXT NOT NULL,
          header TEXT NOT NULL,
          body TEXT NOT NULL,
          button_label TEXT NOT NULL,
          pose_asset TEXT NOT NULL,
          audio_asset TEXT NOT NULL,
          UNIQUE(grade, difficulty)
        )
      ''');
      await db.execute('''
        CREATE TABLE game_intros (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          game_type TEXT NOT NULL UNIQUE,
          header TEXT NOT NULL,
          body TEXT NOT NULL,
          button_label TEXT NOT NULL,
          pose_asset TEXT NOT NULL,
          audio_asset TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 10) {
      try { await db.execute('ALTER TABLE words ADD COLUMN lesson_cue_audio TEXT'); } catch (_) {}
    }
    if (oldVersion < 11) {
      try { await db.execute('ALTER TABLE students ADD COLUMN parent_firebase_uid TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE students ADD COLUMN recovery_email TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE students ADD COLUMN recovery_email_verified INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE parents ADD COLUMN email_verified INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE parents ADD COLUMN phone_number TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE parents ADD COLUMN phone_verified INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE parents ADD COLUMN phone_verified_at TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE parents ADD COLUMN backup_code_hash TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE parents ADD COLUMN backup_code_used INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE parents ADD COLUMN last_synced_at TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE parents ADD COLUMN pending_sync INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE teachers ADD COLUMN email_verified INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE teachers ADD COLUMN phone_number TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE teachers ADD COLUMN phone_verified INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE teachers ADD COLUMN phone_verified_at TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE teachers ADD COLUMN backup_code_hash TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE teachers ADD COLUMN backup_code_used INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE teachers ADD COLUMN last_synced_at TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE teachers ADD COLUMN pending_sync INTEGER DEFAULT 0'); } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS login_attempts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          identifier TEXT NOT NULL,
          attempt_at TEXT NOT NULL,
          success INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pin_attempts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_local_id INTEGER NOT NULL,
          attempt_at TEXT NOT NULL,
          success INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action_type TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          firebase_uid TEXT NOT NULL,
          created_at TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_attempt_at TEXT,
          last_error TEXT
        )
      ''');
    }
    if (oldVersion < 12) {
      try { await db.execute('ALTER TABLE batches ADD COLUMN game_type TEXT'); } catch (_) {}
    }
    if (oldVersion < 13) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lesson_intros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grade INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            header TEXT NOT NULL,
            body TEXT NOT NULL,
            button_label TEXT NOT NULL,
            pose_asset TEXT NOT NULL,
            audio_asset TEXT NOT NULL,
            UNIQUE(grade, difficulty)
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS game_intros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_type TEXT NOT NULL UNIQUE,
            header TEXT NOT NULL,
            body TEXT NOT NULL,
            button_label TEXT NOT NULL,
            pose_asset TEXT NOT NULL,
            audio_asset TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 14) {
      try { await db.execute('ALTER TABLE words ADD COLUMN sample_sentence_audio TEXT'); } catch (_) {}
    }
    if (oldVersion < 15) {
      try { await db.execute('ALTER TABLE batches ADD COLUMN passage_id TEXT'); } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_key TEXT NOT NULL UNIQUE,
            grade_level INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            title TEXT NOT NULL,
            illustration TEXT NOT NULL,
            word_count INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passage_sentences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_id INTEGER NOT NULL,
            sentence_index INTEGER NOT NULL,
            text TEXT NOT NULL,
            audio TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passage_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_id INTEGER NOT NULL,
            stem TEXT NOT NULL,
            question_type TEXT NOT NULL,
            correct_answer TEXT NOT NULL,
            distractors_json TEXT NOT NULL,
            show_image INTEGER DEFAULT 0,
            order_index INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 16) {
      try { await db.execute('DROP TABLE IF EXISTS passage_words'); } catch (_) {}
      try { await db.execute('DROP TABLE IF EXISTS passage_sentences'); } catch (_) {}
      try { await db.execute('DROP TABLE IF EXISTS passages'); } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE passages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_key TEXT NOT NULL UNIQUE,
            grade_level INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            title TEXT NOT NULL,
            illustration TEXT NOT NULL,
            word_count INTEGER NOT NULL,
            tappable_words_json TEXT
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE passage_sentences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_id INTEGER NOT NULL,
            sentence_index INTEGER NOT NULL,
            text TEXT NOT NULL,
            audio TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE passage_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_id INTEGER NOT NULL,
            stem TEXT NOT NULL,
            question_type TEXT NOT NULL,
            correct_answer TEXT NOT NULL,
            distractors_json TEXT NOT NULL,
            show_image INTEGER DEFAULT 0,
            order_index INTEGER NOT NULL,
            stem_audio TEXT,
            FOREIGN KEY (passage_id) REFERENCES passages (id)
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 17) {
      try { await db.execute('DROP TABLE IF EXISTS passage_words'); } catch (_) {}
      try { await db.execute('DROP TABLE IF EXISTS passage_sentences'); } catch (_) {}
      try { await db.execute('DROP TABLE IF EXISTS passages'); } catch (_) {}
      try { await db.execute('DROP TABLE IF EXISTS comprehension_questions'); } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lesson_intros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grade INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            header TEXT NOT NULL,
            body TEXT NOT NULL,
            button_label TEXT NOT NULL,
            pose_asset TEXT NOT NULL,
            audio_asset TEXT NOT NULL,
            UNIQUE(grade, difficulty)
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS game_intros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_type TEXT NOT NULL UNIQUE,
            header TEXT NOT NULL,
            body TEXT NOT NULL,
            button_label TEXT NOT NULL,
            pose_asset TEXT NOT NULL,
            audio_asset TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_key TEXT NOT NULL UNIQUE,
            grade_level INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            title TEXT NOT NULL,
            illustration TEXT NOT NULL,
            word_count INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passage_sentences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_id INTEGER NOT NULL,
            sentence_index INTEGER NOT NULL,
            text TEXT NOT NULL,
            audio TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passage_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_id INTEGER NOT NULL,
            stem TEXT NOT NULL,
            question_type TEXT NOT NULL,
            correct_answer TEXT NOT NULL,
            distractors_json TEXT NOT NULL,
            show_image INTEGER DEFAULT 0,
            order_index INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 18) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_key TEXT NOT NULL UNIQUE,
            grade_level INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            title TEXT NOT NULL,
            illustration TEXT NOT NULL,
            word_count INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passage_sentences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_id INTEGER NOT NULL,
            sentence_index INTEGER NOT NULL,
            text TEXT NOT NULL,
            audio TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS passage_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            passage_id INTEGER NOT NULL,
            stem TEXT NOT NULL,
            question_type TEXT NOT NULL,
            correct_answer TEXT NOT NULL,
            distractors_json TEXT NOT NULL,
            show_image INTEGER DEFAULT 0,
            order_index INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lesson_intros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grade INTEGER NOT NULL,
            difficulty TEXT NOT NULL,
            header TEXT NOT NULL,
            body TEXT NOT NULL,
            button_label TEXT NOT NULL,
            pose_asset TEXT NOT NULL,
            audio_asset TEXT NOT NULL,
            UNIQUE(grade, difficulty)
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS game_intros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_type TEXT NOT NULL UNIQUE,
            header TEXT NOT NULL,
            body TEXT NOT NULL,
            button_label TEXT NOT NULL,
            pose_asset TEXT NOT NULL,
            audio_asset TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try { await db.execute('ALTER TABLE batches ADD COLUMN game_type TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE batches ADD COLUMN passage_id TEXT'); } catch (_) {}
    }
    if (oldVersion < 19) {
      try { await db.execute('ALTER TABLE passage_questions ADD COLUMN stem_audio TEXT'); } catch (_) {}
    }
    if (oldVersion < 20) {
      try { await db.execute('ALTER TABLE passages ADD COLUMN tappable_words_json TEXT'); } catch (_) {}
    }
    if (oldVersion < 21) {
      try { await db.execute('DROP TABLE IF EXISTS opening_frames'); } catch (_) {}
      try { await db.execute('DROP TABLE IF EXISTS story_frames'); } catch (_) {}
    }
    if (oldVersion < 22) {
      try { await db.execute('ALTER TABLE students ADD COLUMN avatar_index INTEGER NOT NULL DEFAULT 1'); } catch (_) {}
    }
  }
}