import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/badge.dart';
import '../models/content_models.dart';
import 'database_service.dart';
import 'firestore_service.dart';

/// Downloads a student's cloud data into local SQLite
/// after cross-device login. Idempotent — safe to call repeatedly.
class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._internal();
  CloudSyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Full download: profile + results + badges + mastery + encounters + starred.
  Future<void> downloadStudentData({
    required int localStudentId,
    required String firebaseUid,
  }) async {
    debugPrint('☁️ Downloading cloud data for $firebaseUid');

    await _downloadProfile(
      localStudentId: localStudentId,
      firebaseUid: firebaseUid,
    );
    await _downloadResults(
      localStudentId: localStudentId,
      firebaseUid: firebaseUid,
    );
    await _downloadBadges(
      localStudentId: localStudentId,
      firebaseUid: firebaseUid,
    );
    await _downloadMastery(
      localStudentId: localStudentId,
      firebaseUid: firebaseUid,
    );
    await _downloadEncounters(
      localStudentId: localStudentId,
      firebaseUid: firebaseUid,
    );
    await _downloadStarred(
      localStudentId: localStudentId,
      firebaseUid: firebaseUid,
    );

    debugPrint('☁️ Download complete');
  }

  // ──────────────────────────────────────────────────────────────
  // Profile
  // ──────────────────────────────────────────────────────────────

  Future<void> _downloadProfile({
    required int localStudentId,
    required String firebaseUid,
  }) async {
    try {
      final doc = await FirestoreService.instance
          .getStudentByUid(firebaseUid);
      if (doc == null) return;

      await DatabaseService.instance.updateStudentFromCloud(
        studentId: localStudentId,
        displayName: (doc['displayName'] ?? '') as String,
        gradeLevel: (doc['gradeLevel'] ?? 1) as int,
        totalPoints: (doc['totalPoints'] ?? 0) as int,
        pinHash: doc['pinHash'] as String?,
        parentFirebaseUid: doc['parentId'] as String?,
        recoveryEmail: doc['recoveryEmail'] as String?,
        className: doc['className'] as String?,
        classFirestoreId: doc['classId'] as String?,
      );
      debugPrint('☁️ Profile: OK');
    } catch (e) {
      debugPrint('☁️ _downloadProfile ERROR: $e');
    }
  }


  // ──────────────────────────────────────────────────────────────
  // Results
  // ──────────────────────────────────────────────────────────────

  Future<void> _downloadResults({
    required int localStudentId,
    required String firebaseUid,
  }) async {
    try {
      final snap = await _db
          .collection('students')
          .doc(firebaseUid)
          .collection('results')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      // Fetch batch mapping once — keyed by remote batchId
      final localBatchIds = await _getLocalBatchIds();

      for (final doc in snap.docs) {
        final data = doc.data();
        final remoteBatchId = data['batchId'] as int?;

        // Match by batchId if present, else fallback by grade+difficulty
        int? localBatchId = remoteBatchId != null
            ? localBatchIds[remoteBatchId]
            : null;

        localBatchId ??= await _fallbackBatchId(
          gradeLevel: (data['gradeLevel'] ?? 0) as int,
          difficulty: (data['difficulty'] ?? 'easy') as String,
        );
        if (localBatchId == null) continue;

        final completedAt = (data['completedAt'] ?? '') as String;
        final exists = await _resultExists(
          localStudentId,
          localBatchId,
          completedAt,
        );
        if (exists) continue;

        await DatabaseService.instance.saveQuizAttempt(
          QuizAttempt(
            studentId: localStudentId,
            batchId: localBatchId,
            score: (data['score'] ?? 0) as int,
            totalQuestions: (data['totalQuestions'] ?? 0) as int,
            pointsEarned: 0, // delta unknown on download
            wrongWordIdsJson: _encodeWrongIds(data['wrongWordIds']),
            completedAt: completedAt,
            syncedToCloud: true,
          ),
        );
      }
      debugPrint('☁️ Results: ${snap.docs.length}');
    } catch (e) {
      debugPrint('☁️ _downloadResults ERROR: $e');
    }
  }

  String? _encodeWrongIds(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) {
      return '[${raw.join(',')}]';
    }
    return null;
  }

  /// Map of {remoteBatchId: localBatchId}.
  Future<Map<int, int>> _getLocalBatchIds() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('batches');
    // Since both local and cloud share the same batchId only if seeded
    // identically, we map by (grade,difficulty,batch_index) to be safe.
    // For now, treat the local id as canonical.
    return {for (final r in rows) r['id'] as int: r['id'] as int};
  }

  Future<int?> _fallbackBatchId({
    required int gradeLevel,
    required String difficulty,
  }) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'batches',
      columns: ['id'],
      where: 'grade_level = ? AND difficulty = ?',
      whereArgs: [gradeLevel, difficulty],
      orderBy: 'batch_index ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<bool> _resultExists(
    int studentId,
    int batchId,
    String completedAt,
  ) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'quiz_attempts',
      where: 'student_id = ? AND batch_id = ? AND completed_at = ?',
      whereArgs: [studentId, batchId, completedAt],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ──────────────────────────────────────────────────────────────
  // Badges
  // ──────────────────────────────────────────────────────────────

  Future<void> _downloadBadges({
    required int localStudentId,
    required String firebaseUid,
  }) async {
    try {
      final snap = await _db
          .collection('students')
          .doc(firebaseUid)
          .collection('badges')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      for (final doc in snap.docs) {
        final data = doc.data();
        await DatabaseService.instance.awardBadge(
          AchievementBadge(
            studentId: localStudentId,
            gradeLevel: (data['gradeLevel'] ?? 0) as int,
            difficulty: (data['difficulty'] ?? 'easy') as String,
            badgeName: (data['badgeName'] ?? '') as String,
            pointsEarned: (data['pointsEarned'] ?? 0) as int,
            earnedAt: (data['earnedAt'] ?? '') as String,
            syncedToCloud: true,
          ),
        );
      }
      debugPrint('☁️ Badges: ${snap.docs.length}');
    } catch (e) {
      debugPrint('☁️ _downloadBadges ERROR: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Word mastery / encounters / starred
  // ──────────────────────────────────────────────────────────────

  Future<void> _downloadMastery({
    required int localStudentId,
    required String firebaseUid,
  }) async {
    try {
      final rows =
          await FirestoreService.instance.pullStudentMastery(firebaseUid);
      for (final r in rows) {
        final wordId = r['wordId'] as int?;
        if (wordId == null) continue;
        await DatabaseService.instance.upsertWordMastery(
          studentId: localStudentId,
          wordId: wordId,
          correctCount: (r['correctCount'] ?? 0) as int,
          wrongCount: (r['wrongCount'] ?? 0) as int,
          masteredAt: r['masteredAt'] as String?,
        );
      }
      debugPrint('☁️ Mastery: ${rows.length}');
    } catch (e) {
      debugPrint('☁️ _downloadMastery ERROR: $e');
    }
  }

  Future<void> _downloadEncounters({
    required int localStudentId,
    required String firebaseUid,
  }) async {
    try {
      final rows =
          await FirestoreService.instance.pullStudentEncounters(firebaseUid);
      for (final r in rows) {
        final wordId = r['wordId'] as int?;
        if (wordId == null) continue;
        await DatabaseService.instance.upsertWordEncounter(
          studentId: localStudentId,
          wordId: wordId,
          firstSeenAt: (r['firstSeenAt'] ?? '') as String,
          timesSeen: (r['timesSeen'] ?? 1) as int,
        );
      }
      debugPrint('☁️ Encounters: ${rows.length}');
    } catch (e) {
      debugPrint('☁️ _downloadEncounters ERROR: $e');
    }
  }

  Future<void> _downloadStarred({
    required int localStudentId,
    required String firebaseUid,
  }) async {
    try {
      final rows =
          await FirestoreService.instance.pullStudentStarred(firebaseUid);
      for (final r in rows) {
        final wordId = r['wordId'] as int?;
        if (wordId == null) continue;
        await DatabaseService.instance.upsertStarredWord(
          studentId: localStudentId,
          wordId: wordId,
          starredAt: (r['starredAt'] ?? '') as String,
        );
      }
      debugPrint('☁️ Starred: ${rows.length}');
    } catch (e) {
      debugPrint('☁️ _downloadStarred ERROR: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Teacher classes
  // ──────────────────────────────────────────────────────────────

  Future<void> downloadTeacherClasses({
    required int localTeacherId,
    required String firebaseUid,
  }) async {
    try {
      final snap = await _db
          .collection('teachers')
          .doc(firebaseUid)
          .collection('classes')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      for (final doc in snap.docs) {
        final data = doc.data();
        await DatabaseService.instance.insertClassGroupIfMissing(
          teacherId: localTeacherId,
          firestoreId: doc.id,
          className: (data['className'] ?? '') as String,
          gradeLevel: (data['gradeLevel'] ?? 1) as int,
          joinCode: (data['joinCode'] ?? '') as String,
        );
      }
      debugPrint('☁️ Teacher classes: ${snap.docs.length}');
    } catch (e) {
      debugPrint('☁️ downloadTeacherClasses ERROR: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Parent children
  // ──────────────────────────────────────────────────────────────

  Future<void> downloadParentChildren({
    required int localParentId,
    required String firebaseUid,
  }) async {
    try {
      final snap = await _db
          .collection('students')
          .where('parentId', isEqualTo: firebaseUid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      for (final doc in snap.docs) {
        final data = doc.data();
        // Now uses UPSERT — updates points if child already exists
        await DatabaseService.instance.insertLinkedChildIfMissing(
          parentId: localParentId,
          firebaseUid: doc.id,
          username: (data['username'] ?? '') as String,
          displayName: (data['displayName'] ?? '') as String,
          gradeLevel: (data['gradeLevel'] ?? 1) as int,
          totalPoints: (data['totalPoints'] ?? 0) as int,
        );
      }
      debugPrint('☁️ Parent children: ${snap.docs.length}');
    } catch (e) {
      debugPrint('☁️ downloadParentChildren ERROR: $e');
    }
  }
}