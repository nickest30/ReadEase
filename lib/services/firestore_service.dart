import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/teacher.dart';
import '../models/class_group.dart';
import '../models/quiz_result.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._internal();
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // TEACHERS
  // ============================================================

  Future<void> saveTeacher(Teacher teacher, String firebaseUid) async {
    try {
      await _db.collection('teachers').doc(firebaseUid).set({
        'username': teacher.username,
        'fullName': teacher.fullName,
        'email': teacher.email,
        'schoolName': teacher.schoolName,
        'firebaseUid': firebaseUid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: saveTeacher($firebaseUid) OK');
    } catch (e) {
      debugPrint('🔥 Firestore saveTeacher ERROR: $e');
    }
  }

  Future<Map<String, dynamic>?> getTeacherByUid(String firebaseUid) async {
    try {
      final doc = await _db.collection('teachers').doc(firebaseUid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('🔥 Firestore getTeacherByUid ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // PARENTS
  // ============================================================

  Future<void> saveParent({
    required String parentUid,
    required String username,
    required String fullName,
    required String email,
  }) async {
    try {
      await _db.collection('parents').doc(parentUid).set({
        'username': username,
        'fullName': fullName,
        'email': email,
        'firebaseUid': parentUid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: saveParent($parentUid) OK');
    } catch (e) {
      debugPrint('🔥 Firestore saveParent ERROR: $e');
    }
  }

  Future<Map<String, dynamic>?> getParentByUid(String parentUid) async {
    try {
      final doc = await _db.collection('parents').doc(parentUid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('🔥 Firestore getParentByUid ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // STUDENTS
  // ============================================================

  /// Save or update a student's basic profile in Firestore.
  /// Called after signup so teacher enrollment rules can verify identity.
  Future<bool> saveStudent(
    String studentUid,
    String displayName,
    int gradeLevel, {
    String? parentId,
    int totalPoints = 0,
    int badgeCount = 0,
  }) async {
    try {
      final data = <String, dynamic>{
        'displayName': displayName,
        'gradeLevel': gradeLevel,
        'totalPoints': totalPoints,
        'badgeCount': badgeCount,
        'firebaseUid': studentUid,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (parentId != null) {
        data['parentId'] = parentId;
      }

      await _db.collection('students').doc(studentUid).set(
            data,
            SetOptions(merge: true),
          );
      debugPrint('🔥 Firestore: saveStudent($studentUid) OK');
      return true;
    } catch (e) {
      debugPrint('🔥 Firestore saveStudent ERROR: $e');
      return false;
    }
  }

  Future<bool> saveLinkedChild({
    required String childUid,
    required String displayName,
    required int gradeLevel,
    required String parentUid,
    int totalPoints = 0,
    int badgeCount = 0,
  }) async {
    try {
      await _db.collection('students').doc(childUid).set({
        'displayName': displayName,
        'gradeLevel': gradeLevel,
        'totalPoints': totalPoints,
        'badgeCount': badgeCount,
        'parentId': parentUid,
        'firebaseUid': childUid,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: saveLinkedChild($childUid) OK');
      return true;
    } catch (e) {
      debugPrint('🔥 Firestore saveLinkedChild ERROR: $e');
      return false;
    }
  }

  /// Fetch all children linked to a parent's UID.
  Future<List<Map<String, dynamic>>> getChildrenOfParent(
      String parentUid) async {
    try {
      final snapshot = await _db
          .collection('students')
          .where('parentId', isEqualTo: parentUid)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('🔥 Firestore getChildrenOfParent ERROR: $e');
      return [];
    }
  }

  /// Fetch a student's quiz results from Firestore.
  Future<List<Map<String, dynamic>>> getStudentResultsFromCloud(
      String studentUid) async {
    try {
      final snapshot = await _db
          .collection('students')
          .doc(studentUid)
          .collection('results')
          .orderBy('completedAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('🔥 Firestore getStudentResultsFromCloud ERROR: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStudentByUid(String studentUid) async {
    try {
      final doc = await _db.collection('students').doc(studentUid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('🔥 Firestore getStudentByUid ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // CLASSES (FLAT — top-level collection)
  // ============================================================

  /// Save a new class.
  /// Writes to BOTH:
  ///   - classes/{classId}                (flat, for join-code lookup)
  ///   - teachers/{uid}/classes/{classId} (nested, for teacher's own list)
  Future<String> saveClassGroup(
    ClassGroup group,
    String teacherUid, {
    String? teacherName,
  }) async {
    try {
      final payload = {
        'className': group.className,
        'gradeLevel': group.gradeLevel,
        'joinCode': group.joinCode.toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // --- Step 1: Nested write ---
      debugPrint('🔥 [1/2] Nested write to teachers/$teacherUid/classes/...');
      final nestedRef = await _db
          .collection('teachers')
          .doc(teacherUid)
          .collection('classes')
          .add(payload);
      final classId = nestedRef.id;
      debugPrint('🔥 [1/2] Nested OK → classId=$classId');

      // --- Step 2: Flat write ---
      debugPrint('🔥 [2/2] Flat write to classes/$classId');
      await _db.collection('classes').doc(classId).set({
        ...payload,
        'teacherUid': teacherUid,
        'teacherName': teacherName ?? '',
        'studentCount': 0,
      });
      debugPrint('🔥 [2/2] Flat OK');

      debugPrint('✅ saveClassGroup COMPLETE → $classId');
      return classId;
    } catch (e, stackTrace) {
      debugPrint('❌ saveClassGroup ERROR: $e');
      debugPrint('❌ STACKTRACE: $stackTrace');
      return '';
    }
  }

  /// Fetch all classes created by a teacher.
  Future<List<Map<String, dynamic>>> getClassesForTeacher(
      String teacherUid) async {
    try {
      final snapshot = await _db
          .collection('teachers')
          .doc(teacherUid)
          .collection('classes')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => {'firestoreId': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('🔥 Firestore getClassesForTeacher ERROR: $e');
      return [];
    }
  }

  /// Look up a class by join code.
  /// Queries the FLAT classes collection — no collection group needed.
  Future<Map<String, dynamic>?> getClassByJoinCode(String joinCode) async {
    try {
      final upperCode = joinCode.toUpperCase();
      debugPrint('🔥 Firestore: searching for joinCode = "$upperCode"');

      final snapshot = await _db
          .collection('classes')
          .where('joinCode', isEqualTo: upperCode)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      debugPrint('🔥 Firestore: found ${snapshot.docs.length} classes');

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      final teacherUid = data['teacherUid'] as String? ?? '';

      debugPrint('🔥 Firestore: matched class "${data['className']}" '
          'from teacher $teacherUid');

      return {
        'firestoreId': doc.id,
        'teacherUid': teacherUid,
        ...data,
      };
    } catch (e) {
      debugPrint('🔥 Firestore getClassByJoinCode ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // ENROLLMENTS
  // ============================================================

  /// Enroll a student in a class.
  Future<bool> enrollStudent({
    required String classId,
    required String studentUid,
    required String studentName,
    required int gradeLevel,
    int totalPoints = 0,
  }) async {
    try {
      // 1. Create enrollment doc
      await _db
          .collection('classes')
          .doc(classId)
          .collection('enrollments')
          .doc(studentUid)
          .set({
        'studentName': studentName,
        'gradeLevel': gradeLevel,
        'totalPoints': totalPoints,
        'enrolledAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔥 [1/2] Enrollment doc created');

      // 2. Update student's classId
      await _db.collection('students').doc(studentUid).set({
        'classId': classId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 [2/2] Student doc updated');

      // Note: studentCount is not incremented here.
      // The teacher-side view computes it from the enrollments list.

      debugPrint('🔥 Firestore: enrollStudent OK ($studentUid → $classId)');
      return true;
    } catch (e) {
      debugPrint('🔥 Firestore enrollStudent ERROR: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getEnrolledStudentsDetailed(
    String classId,
  ) async {
    try {
      // 1. Get enrollment docs
      final enrollments = await getEnrollmentsForClass(classId);

      if (enrollments.isEmpty) return [];

      // 2. Enrich each with student profile data
      final List<Map<String, dynamic>> detailed = [];
      for (final e in enrollments) {
        final uid = e['uid'] as String;
        final profile = await getStudentByUid(uid);

        detailed.add({
          'uid': uid,
          'studentName': e['studentName'] ?? profile?['displayName'] ?? 'Unknown',
          'gradeLevel': e['gradeLevel'] ?? profile?['gradeLevel'] ?? 0,
          'totalPoints': profile?['totalPoints'] ?? e['totalPoints'] ?? 0,
          'badgeCount': profile?['badgeCount'] ?? 0,
          'enrolledAt': e['enrolledAt'],
        });
      }

      // 3. Sort by points (highest first)
      detailed.sort((a, b) =>
          (b['totalPoints'] as int).compareTo(a['totalPoints'] as int));

      return detailed;
    } catch (e) {
      debugPrint('🔥 Firestore getEnrolledStudentsDetailed ERROR: $e');
      return [];
    }
  }

  /// Get all enrollments for a class (for teacher view).
  Future<List<Map<String, dynamic>>> getEnrollmentsForClass(
      String classId) async {
    try {
      final snapshot = await _db
          .collection('classes')
          .doc(classId)
          .collection('enrollments')
          .orderBy('totalPoints', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('🔥 Firestore getEnrollmentsForClass ERROR: $e');
      return [];
    }
  }

  Future<bool> transferStudent({
    required String oldClassId,
    required String newClassId,
    required String studentUid,
    required String studentName,
    required int gradeLevel,
    required int totalPoints,
  }) async {
    try {
      debugPrint('🔥 transferStudent: START');
      debugPrint('🔥   oldClassId: "$oldClassId"');
      debugPrint('🔥   newClassId: "$newClassId"');
      debugPrint('🔥   studentUid: $studentUid');

      // 1. Remove old enrollment
      if (oldClassId.isNotEmpty && oldClassId != newClassId) {
        debugPrint('🔥 [1/3] Deleting old enrollment...');
        try {
          await _db
              .collection('classes')
              .doc(oldClassId)
              .collection('enrollments')
              .doc(studentUid)
              .delete();
          debugPrint('🔥 [1/3] Old enrollment deleted ✓');
        } catch (e) {
          // Log but continue — the important thing is joining the new class
          debugPrint('🔥 [1/3] Could not delete old enrollment (continuing): $e');
        }

        // Try to decrement old class count (best-effort, teacher-only)
        try {
          await _db.collection('classes').doc(oldClassId).update({
            'studentCount': FieldValue.increment(-1),
          });
        } catch (_) {
          debugPrint('🔥 [1/3] Could not decrement old class count (OK)');
        }
      }

      // 2. Add new enrollment
      debugPrint('🔥 [2/3] Creating new enrollment...');
      await _db
          .collection('classes')
          .doc(newClassId)
          .collection('enrollments')
          .doc(studentUid)
          .set({
        'studentName': studentName,
        'gradeLevel': gradeLevel,
        'totalPoints': totalPoints,
        'enrolledAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔥 [2/3] New enrollment created ✓');

      // 3. Update student's current class
      debugPrint('🔥 [3/3] Updating student record...');
      await _db.collection('students').doc(studentUid).set({
        'classId': newClassId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 [3/3] Student record updated ✓');

      // Best-effort: increment new class count
      try {
        await _db.collection('classes').doc(newClassId).update({
          'studentCount': FieldValue.increment(1),
        });
      } catch (_) {
        debugPrint('🔥 [3/3] Could not increment new class count (OK)');
      }

      debugPrint('🔥 transferStudent: COMPLETE ✓');
      return true;
    } catch (e, stackTrace) {
      debugPrint('🔥 transferStudent ERROR: $e');
      debugPrint('🔥 STACKTRACE: $stackTrace');
      return false;
    }
  }

  // ============================================================
  // LEADERBOARD
  // ============================================================

  Future<void> updateLeaderboardEntry({
    required String studentUid,
    required String displayName,
    required int totalPoints,
    required int gradeLevel,
    required int badgeCount,
    String? classId,
  }) async {
    try {
      final data = <String, dynamic>{
        'displayName': displayName,
        'totalPoints': totalPoints,
        'gradeLevel': gradeLevel,
        'badgeCount': badgeCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (classId != null) data['classId'] = classId;

      await _db.collection('leaderboard').doc(studentUid).set(
            data,
            SetOptions(merge: true),
          );
      debugPrint('🔥 Firestore: updateLeaderboardEntry($studentUid) OK');
    } catch (e) {
      debugPrint('🔥 Firestore updateLeaderboardEntry ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({
    int limit = 100,
  }) async {
    try {
      final snapshot = await _db
          .collection('leaderboard')
          .orderBy('totalPoints', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('🔥 Firestore getGlobalLeaderboard ERROR: $e');
      return [];
    }
  }

  /// Class leaderboard — filter by classId.
  Future<List<Map<String, dynamic>>> getClassLeaderboard({
    required String classId,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _db
          .collection('leaderboard')
          .where('classId', isEqualTo: classId)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      final entries = snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();

      // Client-side sort (avoids composite index requirement)
      entries.sort((a, b) =>
          ((b['totalPoints'] ?? 0) as int)
              .compareTo((a['totalPoints'] ?? 0) as int));

      debugPrint('🔥 Firestore: class leaderboard → ${entries.length} entries');
      return entries;
    } catch (e) {
      debugPrint('🔥 Firestore getClassLeaderboard ERROR: $e');
      return [];
    }
  }

  // ============================================================
  // PROGRESS SYNC (M4)
  // ============================================================

  /// Sync a student's quiz results + progress to Firestore.
  /// Deferred to M4 — kept here for API stability.
  Future<void> syncStudentProgress(
    String studentUid,
    String studentName,
    int totalPoints,
    List<QuizResult> results,
  ) async {
    try {
      // Write each result as a nested doc
      for (final r in results) {
        if (r.id == null) continue;
        await _db
            .collection('students')
            .doc(studentUid)
            .collection('results')
            .doc('result_${r.id}')
            .set({
          'gradeLevel': r.gradeLevel,
          'difficulty': r.difficulty,
          'score': r.score,
          'totalQuestions': r.totalQuestions,
          'pointsEarned': r.pointsEarned,
          'isPassing': r.isPassing,
          'completedAt': r.completedAt,
        }, SetOptions(merge: true));
      }

      await _db.collection('students').doc(studentUid).set({
        'displayName': studentName,
        'totalPoints': totalPoints,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('🔥 Firestore: syncStudentProgress($studentUid) OK');
    } catch (e) {
      debugPrint('🔥 Firestore syncStudentProgress ERROR: $e');
    }
  }
}