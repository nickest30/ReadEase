import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/word.dart';
import '../models/quiz_result.dart';
import '../models/parent.dart';

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
      version: 1,
      onCreate: _createTables,
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
        created_at TEXT NOT NULL
      )
    ''');
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

  Future<int> updateStudentDisplayName(int studentId, String displayName) async {
    final db = await database;
    return await db.update(
      'students',
      {'display_name': displayName},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  Future<int> deleteStudent(int studentId) async {
    final db = await database;
    return await db.delete(
      'students', where: 'id = ?', whereArgs: [studentId],
    );
  }
}