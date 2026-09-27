import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../providers/connectivity_provider.dart';
import 'database_service.dart';
import 'firestore_service.dart';

/// Handles retrying cloud sync operations when the app opens.
/// Call `SyncService.instance.retryPendingSyncs(...)` after login.
class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  bool _running = false;

  /// Retry any pending quiz result syncs for this student.
  /// Safe to call multiple times — guards against concurrent runs.
  Future<void> retryPendingSyncs({
    required Student student,
    required ConnectivityProvider connectivity,
  }) async {
    if (_running) {
      debugPrint('🔄 Sync: already running, skipping');
      return;
    }

    if (student.firebaseUid == null) {
      debugPrint('🔄 Sync: no Firebase UID, skipping');
      return;
    }

    if (!connectivity.isOnline) {
      debugPrint('🔄 Sync: offline, skipping');
      return;
    }

    _running = true;
    try {
      final pending = await DatabaseService.instance
          .getPendingSyncResults(student.id!);

      if (pending.isEmpty) {
        debugPrint('🔄 Sync: no pending results');
        return;
      }

      debugPrint('🔄 Sync: retrying ${pending.length} pending results...');

      // Fetch all results (both synced + pending) for full progress sync
      final allResults = await DatabaseService.instance
          .getResultsForStudent(student.id!);

      // Recompute badge count
      final Set<String> passedKeys = {};
      for (final r in allResults) {
        if (r.isPassing) {
          passedKeys.add('${r.gradeLevel}-${r.difficulty}');
        }
      }

      // Sync progress (writes all results, idempotent)
      await FirestoreService.instance.syncStudentProgress(
        student.firebaseUid!,
        student.displayName,
        student.totalPoints,
        allResults,
      );

      // Update leaderboard entry
      await FirestoreService.instance.updateLeaderboardEntry(
        studentUid: student.firebaseUid!,
        displayName: student.displayName,
        totalPoints: student.totalPoints,
        gradeLevel: student.gradeLevel,
        badgeCount: passedKeys.length,
        classId: student.classFirestoreId,
      );

      // Mark all pending results as synced
      for (final r in pending) {
        if (r.id != null) {
          await DatabaseService.instance.markResultSynced(r.id!);
        }
      }

      debugPrint('🔄 Sync: ${pending.length} results synced ✓');
    } catch (e) {
      debugPrint('🔄 Sync failed (will retry next time): $e');
    } finally {
      _running = false;
    }
  }
}