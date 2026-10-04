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
        'emailVerified': teacher.emailVerified,
        'phoneNumber': teacher.phoneNumber,
        'phoneVerified': teacher.phoneVerified,
        'phoneVerifiedAt': teacher.phoneVerifiedAt,
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
    bool emailVerified = false,
    String? phoneNumber,
    bool phoneVerified = false,
    String? phoneVerifiedAt,
  }) async {
    try {
      await _db.collection('parents').doc(parentUid).set({
        'username': username,
        'fullName': fullName,
        'email': email,
        'emailVerified': emailVerified,
        'phoneNumber': phoneNumber,
        'phoneVerified': phoneVerified,
        'phoneVerifiedAt': phoneVerifiedAt,
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
      final doc = await _db
          .collection('parents')
          .doc(parentUid)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return null;
      return {'uid': doc.id, ...doc.data()!};
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
    String? username,             // NEW — required for cross-device lookup
    String? parentId,             // legacy int-hash form (kept for compat)
    String? parentFirebaseUid,    // NEW — real Firestore UID
    String? pinHash,              // NEW — for new-device PIN verification
    int totalPoints = 0,
    int badgeCount = 0,
    bool includePoints = true,    // NEW — set false if using incrementStudentPoints
  }) async {
    try {
      final data = <String, dynamic>{
        'displayName': displayName,
        'gradeLevel': gradeLevel,
        'firebaseUid': studentUid,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (username != null) data['username'] = username.toLowerCase();
      if (pinHash != null) data['pinHash'] = pinHash;

      if (includePoints) {
        data['totalPoints'] = totalPoints;
        data['badgeCount'] = badgeCount;
      }

      if (parentFirebaseUid != null) {
        data['parentId'] = parentFirebaseUid;
        data['isLinked'] = true;
      } else if (parentId != null) {
        // legacy path
        data['parentId'] = parentId;
        data['isLinked'] = true;
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

  /// Look up a student by username (queries Firestore for cross-device login).
  Future<Map<String, dynamic>?> getStudentByUsername(String username) async {
    try {
      final snapshot = await _db
          .collection('students')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) {
        debugPrint('🔥 getStudentByUsername: "$username" not found in cloud');
        return null;
      }

      final doc = snapshot.docs.first;
      debugPrint('🔥 getStudentByUsername: found "$username" (${doc.id})');
      return {'uid': doc.id, ...doc.data()};
    } catch (e) {
      debugPrint('🔥 getStudentByUsername ERROR: $e');
      return null;
    }
  }

  Future<bool> saveLinkedChild({
    required String childUid,
    required String username,
    required String displayName,
    required int gradeLevel,
    required String parentUid,
    String? pinHash,              // NEW
    int totalPoints = 0,
    int badgeCount = 0,
    bool isLinked = true,
  }) async {
    try {
      final data = <String, dynamic>{
        'username': username.toLowerCase(),
        'displayName': displayName,
        'gradeLevel': gradeLevel,
        'totalPoints': totalPoints,
        'badgeCount': badgeCount,
        'parentId': parentUid,
        'isLinked': isLinked,
        'firebaseUid': childUid,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (pinHash != null) data['pinHash'] = pinHash;

      await _db.collection('students').doc(childUid).set(
            data,
            SetOptions(merge: true),
          );
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


  // ============================================================
  // LINK CODES — Parent generates, child redeems
  // ============================================================

  /// Generate a 6-char link code valid for 24 hours.
  Future<String?> generateLinkCode({
    required String parentUid,
    required String parentName,
  }) async {
    try {
      final code = _generateCode();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      debugPrint('🔥 generateLinkCode: START');
      debugPrint('🔥   code: $code');
      debugPrint('🔥   parentUid: $parentUid');
      debugPrint('🔥   parentName: $parentName');
      debugPrint('🔥   expiresAt: ${expiresAt.toIso8601String()}');

      await _db.collection('link_codes').doc(code).set({
        'parentUid': parentUid,
        'parentName': parentName,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      debugPrint('🔥 generateLinkCode: SUCCESS → $code');
      return code;
    } catch (e, stackTrace) {
      debugPrint('🔥 generateLinkCode ERROR: $e');
      debugPrint('🔥 STACKTRACE: $stackTrace');
      return null;
    }
  }

  /// Validate a link code. Returns parent info if valid.
  Future<Map<String, dynamic>?> validateLinkCode(String rawCode) async {
    try {
      final code = rawCode.trim().toUpperCase();
      final doc = await _db.collection('link_codes').doc(code).get();

      if (!doc.exists) {
        debugPrint('🔥 validateLinkCode: code not found');
        return null;
      }

      final data = doc.data()!;
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt == null) return null;

      if (expiresAt.toDate().isBefore(DateTime.now())) {
        debugPrint('🔥 validateLinkCode: code expired');
        return null;
      }

      return {
        'code': doc.id,
        'parentUid': data['parentUid'],
        'parentName': data['parentName'],
        'expiresAt': expiresAt.toDate().toIso8601String(),
      };
    } catch (e) {
      debugPrint('🔥 Firestore validateLinkCode ERROR: $e');
      return null;
    }
  }

  /// Link a student to a parent via a validated code.
  Future<bool> linkStudentToParent({
    required String studentUid,
    required String parentUid,
  }) async {
    try {
      await _db.collection('students').doc(studentUid).set({
        'parentId': parentUid,
        'isLinked': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: linkStudentToParent OK');
      return true;
    } catch (e) {
      debugPrint('🔥 Firestore linkStudentToParent ERROR: $e');
      return false;
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final seed = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    int s = seed;
    for (int i = 0; i < 6; i++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      code += chars[s % chars.length];
    }
    return code;
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
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '🔥 getStudentResultsFromCloud($studentUid): '
        '${snapshot.docs.length} results',
      );

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('🔥 Firestore getStudentResultsFromCloud ERROR: $e');
      // Fall back to cache
      try {
        final snapshot = await _db
            .collection('students')
            .doc(studentUid)
            .collection('results')
            .orderBy('completedAt', descending: true)
            .get();
        return snapshot.docs.map((doc) => doc.data()).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<Map<String, dynamic>?> getStudentByUid(String studentUid) async {
    try {
      final doc = await _db
          .collection('students')
          .doc(studentUid)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return null;
      return {'uid': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('🔥 Firestore getStudentByUid ERROR: $e');
      // Fall back to cache
      try {
        final doc =
            await _db.collection('students').doc(studentUid).get();
        if (!doc.exists) return null;
        return {'uid': doc.id, ...doc.data()!};
      } catch (_) {
        return null;
      }
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

  Future<Map<String, dynamic>?> getTeacherByUidFull(String teacherUid) async {
    try {
      final doc = await _db
          .collection('teachers')
          .doc(teacherUid)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return null;
      return {'uid': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('🔥 Firestore getTeacherByUidFull ERROR: $e');
      return null;
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
        .get(const GetOptions(source: Source.server));

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

      try {
        await _db.collection('leaderboard').doc(studentUid).set({
          'displayName': studentName,
          'totalPoints': totalPoints,
          'gradeLevel': gradeLevel,
          'classId': newClassId,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('🔥 transferStudent: leaderboard updated with name + points');
      } catch (e) {
        debugPrint('🔥 transferStudent: leaderboard update failed (continuing): $e');
      }

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

  /// Update a student's points snapshot in their class enrollment doc.
  /// Called after every quiz so the teacher view stays fresh.
  Future<void> updateEnrollmentSnapshot({
    required String classId,
    required String studentUid,
    required int totalPoints,
    required int badgeCount,
  }) async {
    try {
      await _db
          .collection('classes')
          .doc(classId)
          .collection('enrollments')
          .doc(studentUid)
          .set({
        'totalPoints': totalPoints,
        'badgeCount': badgeCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: enrollment snapshot updated');
    } catch (e) {
      debugPrint('🔥 Firestore updateEnrollmentSnapshot ERROR: $e');
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
      debugPrint('🏆 getClassLeaderboard: querying classId=$classId');
      final snapshot = await _db
          .collection('leaderboard')
          .where('classId', isEqualTo: classId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      debugPrint('🏆 getClassLeaderboard: found ${snapshot.docs.length} entries');

      final entries = snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
      entries.sort((a, b) =>
          ((b['totalPoints'] ?? 0) as int)
              .compareTo((a['totalPoints'] ?? 0) as int));
      return entries;
    } catch (e) {
      debugPrint('🏆 getClassLeaderboard ERROR: $e');
      return [];
    }
  }

  // ============================================================
  // PROGRESS SYNC (M4)
  // ============================================================

  /// Push a single quiz attempt to students/{uid}/results/{attemptId}.
  /// Uses a deterministic docId based on completedAt to be idempotent.
  Future<bool> pushQuizAttempt({
    required String studentUid,
    required int localAttemptId,
    required int batchId,
    required int gradeLevel,
    required String difficulty,
    required int score,
    required int totalQuestions,
    required int pointsEarned,
    required List<int> wrongWordIds,
    required String completedAt,
  }) async {
    try {
      final docId = 'attempt_$localAttemptId';
      await _db
          .collection('students')
          .doc(studentUid)
          .collection('results')
          .doc(docId)
          .set({
        'batchId': batchId,
        'gradeLevel': gradeLevel,
        'difficulty': difficulty,
        'score': score,
        'totalQuestions': totalQuestions,
        'pointsEarned': pointsEarned,
        'wrongWordIds': wrongWordIds,
        'completedAt': completedAt,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 pushQuizAttempt($docId) OK');
      return true;
    } catch (e) {
      debugPrint('🔥 pushQuizAttempt ERROR: $e');
      return false;
    }
  }

  /// Legacy method — kept for any remaining callers.
  /// @Deprecated: use pushQuizAttempt for the new QuizAttempt flow.
  Future<void> syncStudentProgress(
    String studentUid,
    String studentName,
    int totalPoints,
    List<QuizResult> results,
  ) async {
    // Kept as-is for backward compat, but new code should use pushQuizAttempt.
    try {
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

  /// Sync a badge to Firestore under students/{uid}/badges/.
  Future<void> syncBadge({
    required String studentUid,
    required String badgeKey,  // "grade-difficulty", e.g. "1-easy"
    required int gradeLevel,
    required String difficulty,
    required String badgeName,
    required int pointsEarned,
    required String earnedAt,
  }) async {
    try {
      await _db
          .collection('students')
          .doc(studentUid)
          .collection('badges')
          .doc(badgeKey)
          .set({
        'gradeLevel': gradeLevel,
        'difficulty': difficulty,
        'badgeName': badgeName,
        'pointsEarned': pointsEarned,
        'earnedAt': earnedAt,
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: syncBadge($badgeKey) OK');
    } catch (e) {
      debugPrint('🔥 Firestore syncBadge ERROR: $e');
    }
  }


  // ============================================================
  // ATOMIC UPDATES
  // ============================================================

  /// Atomically increment a student's total points.
  /// Use this instead of absolute `saveStudent(totalPoints: X)` to avoid
  /// lost updates when two devices sync simultaneously.
  Future<void> incrementStudentPoints(String studentUid, int delta) async {
    if (delta == 0) return;
    try {
      await _db.collection('students').doc(studentUid).set({
        'totalPoints': FieldValue.increment(delta),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: incrementStudentPoints($studentUid, +$delta)');
    } catch (e) {
      debugPrint('🔥 incrementStudentPoints ERROR: $e');
    }
  }

  // ============================================================
  // EMAIL / PHONE VERIFICATION MARKERS
  // ============================================================

  /// Mark email as verified in Firestore for parent or teacher.
  Future<void> markEmailVerified(String uid, String role) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'emailVerified': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: markEmailVerified($uid, $role)');
    } catch (e) {
      debugPrint('🔥 markEmailVerified ERROR: $e');
    }
  }

  /// Mark phone as verified in Firestore for parent or teacher.
  Future<void> markPhoneVerified(String uid, String role) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'phoneVerified': true,
        'phoneVerifiedAt': DateTime.now().toIso8601String(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: markPhoneVerified($uid, $role)');
    } catch (e) {
      debugPrint('🔥 markPhoneVerified ERROR: $e');
    }
  }

  /// Save the backup code bcrypt hash at signup time.
  Future<void> saveBackupCodeHash(
    String uid,
    String role,
    String hash,
  ) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'backupCodeHash': hash,
        'backupCodeUsed': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: saveBackupCodeHash($uid, $role)');
    } catch (e) {
      debugPrint('🔥 saveBackupCodeHash ERROR: $e');
    }
  }

  /// Replace the backup code hash after a successful use.
  /// Backup codes are single-use; a new one is always generated.
  Future<void> rotateBackupCode(
    String uid,
    String role,
    String newHash,
  ) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'backupCodeHash': newHash,
        'backupCodeUsed': false,
        'backupCodeRotatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: rotateBackupCode($uid, $role)');
    } catch (e) {
      debugPrint('🔥 rotateBackupCode ERROR: $e');
    }
  }

  // ============================================================
  // WORD ANALYTICS SYNC (mastery, encounters, starred)
  // ============================================================

  /// Push a word_mastery row to students/{uid}/mastery/{wordId}.
  Future<void> syncWordMastery({
    required String studentUid,
    required int wordId,
    required int correctCount,
    required int wrongCount,
    String? masteredAt,
  }) async {
    try {
      await _db
          .collection('students')
          .doc(studentUid)
          .collection('mastery')
          .doc(wordId.toString())
          .set({
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'masteredAt': masteredAt,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('🔥 syncWordMastery ERROR: $e');
    }
  }

  /// Push a word_encounter row to students/{uid}/encounters/{wordId}.
  Future<void> syncWordEncounter({
    required String studentUid,
    required int wordId,
    required String firstSeenAt,
    required int timesSeen,
  }) async {
    try {
      await _db
          .collection('students')
          .doc(studentUid)
          .collection('encounters')
          .doc(wordId.toString())
          .set({
        'firstSeenAt': firstSeenAt,
        'timesSeen': timesSeen,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('🔥 syncWordEncounter ERROR: $e');
    }
  }

  /// Push a starred word to students/{uid}/starred/{wordId}.
  Future<void> syncStarredWord({
    required String studentUid,
    required int wordId,
    required String starredAt,
  }) async {
    try {
      await _db
          .collection('students')
          .doc(studentUid)
          .collection('starred')
          .doc(wordId.toString())
          .set({
        'starredAt': starredAt,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('🔥 syncStarredWord ERROR: $e');
    }
  }

  /// Remove a starred word from cloud (when unstarred).
  Future<void> unsyncStarredWord({
    required String studentUid,
    required int wordId,
  }) async {
    try {
      await _db
          .collection('students')
          .doc(studentUid)
          .collection('starred')
          .doc(wordId.toString())
          .delete();
    } catch (e) {
      debugPrint('🔥 unsyncStarredWord ERROR: $e');
    }
  }


  // ============================================================
  // WORD ANALYTICS PULL (for cross-device download)
  // ============================================================

  Future<List<Map<String, dynamic>>> pullStudentMastery(String studentUid) async {
    try {
      final snap = await _db
          .collection('students')
          .doc(studentUid)
          .collection('mastery')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      return snap.docs
          .map((d) => {'wordId': int.tryParse(d.id), ...d.data()})
          .toList();
    } catch (e) {
      debugPrint('🔥 pullStudentMastery ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentEncounters(String studentUid) async {
    try {
      final snap = await _db
          .collection('students')
          .doc(studentUid)
          .collection('encounters')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      return snap.docs
          .map((d) => {'wordId': int.tryParse(d.id), ...d.data()})
          .toList();
    } catch (e) {
      debugPrint('🔥 pullStudentEncounters ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentStarred(String studentUid) async {
    try {
      final snap = await _db
          .collection('students')
          .doc(studentUid)
          .collection('starred')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      return snap.docs
          .map((d) => {'wordId': int.tryParse(d.id), ...d.data()})
          .toList();
    } catch (e) {
      debugPrint('🔥 pullStudentStarred ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> pullStudentBadges(String studentUid) async {
    try {
      final snap = await _db
          .collection('students')
          .doc(studentUid)
          .collection('badges')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      return snap.docs.map((d) => {'badgeKey': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('🔥 pullStudentBadges ERROR: $e');
      return [];
    }
  }

  /// Full parent doc with uid field (mirrors getTeacherByUidFull).
  Future<Map<String, dynamic>?> getParentByUidFull(String parentUid) async {
    try {
      final doc = await _db
          .collection('parents')
          .doc(parentUid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (!doc.exists) return null;
      return {'uid': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('🔥 getParentByUidFull ERROR: $e');
      // Fall back to cache
      try {
        final doc = await _db.collection('parents').doc(parentUid).get();
        if (!doc.exists) return null;
        return {'uid': doc.id, ...doc.data()!};
      } catch (_) {
        return null;
      }
    }
  }


  /// Save the raw phone number at signup, before verification.
  /// `phoneVerified` is set to false; a separate call to
  /// `markPhoneVerified()` flips it after the OTP succeeds.
  Future<void> markPhoneNumber(
    String uid,
    String role,
    String phoneNumber,
  ) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'phoneNumber': phoneNumber,
        'phoneVerified': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔥 Firestore: markPhoneNumber($uid, $role)');
    } catch (e) {
      debugPrint('🔥 markPhoneNumber ERROR: $e');
    }
  }

}