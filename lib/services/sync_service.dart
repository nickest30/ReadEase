import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import 'database_service.dart';
import 'firestore_service.dart';

/// Orchestrates cloud push of local data (quiz attempts, badges, mastery,
/// encounters, starred words, leaderboard).
///
/// Call `syncAll()` after login, on offline→online transition, and after
/// any local write that needs cloud persistence.
class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  bool _running = false;

  /// Push everything pending for this student to Firestore.
  /// Safe to call multiple times — guarded against concurrent runs.
  ///
  /// Ensures the Firebase Auth session is active for this student before
  /// writing — without it, all Firestore writes fail with PERMISSION_DENIED.
  Future<void> syncAll({
    required Student student,
    required ConnectivityProvider connectivity,
    required AuthProvider authProvider,
  }) async {
    if (_running) {
      debugPrint('🔄 Sync: already running, skipping');
      return;
    }

    final uid = student.firebaseUid;
    final localId = student.id;
    if (uid == null || localId == null) {
      debugPrint('🔄 Sync: no Firebase UID or local ID, skipping');
      return;
    }

    if (!connectivity.isOnline) {
      debugPrint('🔄 Sync: offline, skipping');
      return;
    }

    // ── Ensure Firebase Auth session is active for this student ──
    // Without this, all Firestore writes below fail with PERMISSION_DENIED.
    if (authProvider.uid != uid) {
      debugPrint('🔄 Sync: restoring session for $uid');
      final restored = await authProvider.tryRestoreSessionFor(uid: uid);
      if (!restored) {
        debugPrint('🔄 Sync: could not restore session — aborting');
        return;
      }
    }

    _running = true;
    try {
      await _pushQuizAttempts(student);
      await _pushBadges(student);
      await _pushMastery(student);
      await _pushEncounters(student);
      await _pushStarred(student);
      await _updateLeaderboard(student);

      debugPrint('🔄 Sync: complete ✓');
    } catch (e, stack) {
      debugPrint('🔄 Sync failed (will retry next time): $e');
      debugPrint('🔄 STACK: $stack');
    } finally {
      _running = false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Quiz attempts
  // ──────────────────────────────────────────────────────────────

  Future<void> _pushQuizAttempts(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final pending = await DatabaseService.instance
        .getPendingSyncAttempts(localId);

    if (pending.isEmpty) {
      debugPrint('🔄 Sync: no pending quiz attempts');
      return;
    }

    debugPrint('🔄 Sync: pushing ${pending.length} quiz attempts');

    for (final attempt in pending) {
      // Look up the batch to derive grade + difficulty
      final batch = await DatabaseService.instance
          .getBatchById(attempt.batchId);
      if (batch == null) {
        debugPrint('🔄 Sync: batch ${attempt.batchId} not found — skipping');
        continue;
      }

      final wrongIds = _parseWrongWordIds(attempt.wrongWordIdsJson);

      final ok = await FirestoreService.instance.pushQuizAttempt(
        studentUid: uid,
        localAttemptId: attempt.id!,
        batchId: attempt.batchId,
        gradeLevel: batch.gradeLevel,
        difficulty: batch.difficulty,
        score: attempt.score,
        totalQuestions: attempt.totalQuestions,
        pointsEarned: attempt.pointsEarned,
        wrongWordIds: wrongIds,
        completedAt: attempt.completedAt,
      );

      if (ok) {
        await DatabaseService.instance.markAttemptSynced(attempt.id!);

        // Increment cloud total points atomically
        if (attempt.pointsEarned > 0) {
          await FirestoreService.instance.incrementStudentPoints(
            uid,
            attempt.pointsEarned,
          );
        }
      }
    }
  }

  List<int> _parseWrongWordIds(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final cleaned = json.replaceAll('[', '').replaceAll(']', '');
      if (cleaned.isEmpty) return [];
      return cleaned
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Badges
  // ──────────────────────────────────────────────────────────────

  Future<void> _pushBadges(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final pending = await DatabaseService.instance
        .getPendingSyncBadges(localId);

    if (pending.isEmpty) return;

    debugPrint('🔄 Sync: pushing ${pending.length} badges');

    for (final badge in pending) {
      final badgeKey = '${badge.gradeLevel}-${badge.difficulty}';
      await FirestoreService.instance.syncBadge(
        studentUid: uid,
        badgeKey: badgeKey,
        gradeLevel: badge.gradeLevel,
        difficulty: badge.difficulty,
        badgeName: badge.badgeName,
        pointsEarned: badge.pointsEarned,
        earnedAt: badge.earnedAt,
      );
      if (badge.id != null) {
        await DatabaseService.instance.markBadgeSynced(badge.id!);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Word mastery
  // ──────────────────────────────────────────────────────────────

  Future<void> _pushMastery(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final masteries =
        await DatabaseService.instance.getMasteryForStudent(localId);
    if (masteries.isEmpty) return;

    debugPrint('🔄 Sync: pushing ${masteries.length} mastery rows');

    for (final m in masteries) {
      await FirestoreService.instance.syncWordMastery(
        studentUid: uid,
        wordId: m.wordId,
        correctCount: m.correctCount,
        wrongCount: m.wrongCount,
        masteredAt: m.masteredAt,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Word encounters
  // ──────────────────────────────────────────────────────────────

  Future<void> _pushEncounters(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final encounters =
        await DatabaseService.instance.getEncountersForStudent(localId);
    if (encounters.isEmpty) return;

    debugPrint('🔄 Sync: pushing ${encounters.length} encounters');

    for (final e in encounters) {
      await FirestoreService.instance.syncWordEncounter(
        studentUid: uid,
        wordId: e.wordId,
        firstSeenAt: e.firstSeenAt,
        timesSeen: e.timesSeen,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Starred words
  // ──────────────────────────────────────────────────────────────

  Future<void> _pushStarred(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final starred =
        await DatabaseService.instance.getStarredWordsForStudent(localId);
    if (starred.isEmpty) return;

    debugPrint('🔄 Sync: pushing ${starred.length} starred');

    for (final s in starred) {
      await FirestoreService.instance.syncStarredWord(
        studentUid: uid,
        wordId: s.wordId,
        starredAt: s.starredAt,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Leaderboard
  // ──────────────────────────────────────────────────────────────

  Future<void> _updateLeaderboard(Student student) async {
    final uid = student.firebaseUid!;

    final badges = await DatabaseService.instance
        .getBadgesForStudent(student.id!);

    await FirestoreService.instance.updateLeaderboardEntry(
      studentUid: uid,
      displayName: student.displayName,
      totalPoints: student.totalPoints,
      gradeLevel: student.gradeLevel,
      badgeCount: badges.length,
      classId: student.classFirestoreId,
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Legacy alias (keeps old callers working)
  // ──────────────────────────────────────────────────────────────

  @Deprecated('Use syncAll() instead')
  Future<void> retryPendingSyncs({
    required Student student,
    required ConnectivityProvider connectivity,
    required AuthProvider authProvider,
  }) =>
      syncAll(
        student: student,
        connectivity: connectivity,
        authProvider: authProvider,
      );
}