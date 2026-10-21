import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import 'database_service.dart';
import 'firestore_service.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  bool _running = false;

  Future<void> syncAll({
    required Student student,
    required ConnectivityProvider connectivity,
    required AuthProvider authProvider,
  }) async {
    if (_running) return;

    final uid = student.firebaseUid;
    final localId = student.id;
    if (uid == null || localId == null) return;

    if (!connectivity.isOnline) return;

    if (authProvider.uid != uid) {
      final restored = await authProvider.tryRestoreSessionFor(uid: uid);
      if (!restored) return;
    }

    _running = true;
    try {
      await _pushProfile(student);
      await _pushQuizAttempts(student);
      await _pushBadges(student);
      await _pushMastery(student);
      await _pushEncounters(student);
      await _pushStarred(student);
      await _updateLeaderboard(student);

      debugPrint('Sync: complete');
    } catch (e, stack) {
      debugPrint('Sync failed: $e');
      debugPrint('STACK: $stack');
    } finally {
      _running = false;
    }
  }

  Future<void> _pushQuizAttempts(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final pending = await DatabaseService.instance
        .getPendingSyncAttempts(localId);

    if (pending.isEmpty) return;

    for (final attempt in pending) {
      final batch = await DatabaseService.instance
          .getBatchById(attempt.batchId);
      if (batch == null) continue;

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

        if (attempt.pointsEarned > 0) {
          await FirestoreService.instance.incrementStudentPoints(
            uid,
            attempt.pointsEarned,
          );
        }
      }
    }
  }

  Future<void> _pushProfile(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final fresh = await DatabaseService.instance.getStudentById(localId);
    final source = fresh ?? student;

    await FirestoreService.instance.saveStudent(
      uid,
      source.displayName,
      source.gradeLevel,
      username: source.username,
      avatarIndex: source.avatarIndex,
      includePoints: false,
    );
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

  Future<void> _pushBadges(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final pending = await DatabaseService.instance
        .getPendingSyncBadges(localId);

    if (pending.isEmpty) return;

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

  Future<void> _pushMastery(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final masteries =
        await DatabaseService.instance.getMasteryForStudent(localId);
    if (masteries.isEmpty) return;

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

  Future<void> _pushEncounters(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final encounters =
        await DatabaseService.instance.getEncountersForStudent(localId);
    if (encounters.isEmpty) return;

    for (final e in encounters) {
      await FirestoreService.instance.syncWordEncounter(
        studentUid: uid,
        wordId: e.wordId,
        firstSeenAt: e.firstSeenAt,
        timesSeen: e.timesSeen,
      );
    }
  }

  Future<void> _pushStarred(Student student) async {
    final uid = student.firebaseUid!;
    final localId = student.id!;

    final starred =
        await DatabaseService.instance.getStarredWordsForStudent(localId);
    if (starred.isEmpty) return;

    for (final s in starred) {
      await FirestoreService.instance.syncStarredWord(
        studentUid: uid,
        wordId: s.wordId,
        starredAt: s.starredAt,
      );
    }
  }

  Future<void> _updateLeaderboard(Student student) async {
    final uid = student.firebaseUid!;

    final fresh =
        await DatabaseService.instance.getStudentById(student.id!);
    final source = fresh ?? student;

    final badges = await DatabaseService.instance
        .getBadgesForStudent(source.id!);

    await FirestoreService.instance.updateLeaderboardEntry(
      studentUid: uid,
      displayName: source.displayName,
      totalPoints: source.totalPoints,
      gradeLevel: source.gradeLevel,
      badgeCount: badges.length,
      classId: source.classFirestoreId,
      avatarIndex: source.avatarIndex,
    );

    if (source.classFirestoreId != null &&
        source.classFirestoreId!.isNotEmpty) {
      await FirestoreService.instance.updateEnrollmentSnapshot(
        classId: source.classFirestoreId!,
        studentUid: uid,
        totalPoints: source.totalPoints,
        badgeCount: badges.length,
        avatarIndex: source.avatarIndex,
      );
    }
  }

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