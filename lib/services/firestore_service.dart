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
      debugPrint('Firestore: saveTeacher($firebaseUid) OK');
    } catch (e) {
      debugPrint('Firestore saveTeacher ERROR: $e');
    }
  }

  Future<Map<String, dynamic>?> getTeacherByUid(String firebaseUid) async {
    try {
      final doc = await _db.collection('teachers').doc(firebaseUid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('Firestore getTeacherByUid ERROR: $e');
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
      debugPrint('Firestore: saveParent($parentUid) OK');
    } catch (e) {
      debugPrint('Firestore saveParent ERROR: $e');
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
      debugPrint('Firestore getParentByUid ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // STUDENTS
  // ============================================================

  Future<bool> saveStudent(
    String studentUid,
    String displayName,
    int gradeLevel, {
    String? username,
    String? parentId,
    String? parentFirebaseUid,
    String? pinHash,
    int totalPoints = 0,
    int badgeCount = 0,
    bool includePoints = true,
    int? avatarIndex,
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
      if (avatarIndex != null) data['avatarIndex'] = avatarIndex;

      if (includePoints) {
        data['totalPoints'] = totalPoints;
        data['badgeCount'] = badgeCount;
      }

      if (parentFirebaseUid != null) {
        data['parentId'] = parentFirebaseUid;
        data['isLinked'] = true;
      } else if (parentId != null) {
        data['parentId'] = parentId;
        data['isLinked'] = true;
      }

      await _db.collection('students').doc(studentUid).set(
            data,
            SetOptions(merge: true),
          );
      debugPrint('Firestore: saveStudent($studentUid) OK');
      return true;
    } catch (e) {
      debugPrint('Firestore saveStudent ERROR: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStudentByUsername(String username) async {
    try {
      final snapshot = await _db
          .collection('students')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return {'uid': doc.id, ...doc.data()};
    } catch (e) {
      debugPrint('Firestore getStudentByUsername ERROR: $e');
      return null;
    }
  }

  Future<bool> saveLinkedChild({
    required String childUid,
    required String username,
    required String displayName,
    required int gradeLevel,
    required String parentUid,
    String? pinHash,
    int totalPoints = 0,
    int badgeCount = 0,
    bool isLinked = true,
    int? avatarIndex,
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
      if (avatarIndex != null) data['avatarIndex'] = avatarIndex;

      await _db.collection('students').doc(childUid).set(
            data,
            SetOptions(merge: true),
          );
      debugPrint('Firestore: saveLinkedChild($childUid) OK');
      return true;
    } catch (e) {
      debugPrint('Firestore saveLinkedChild ERROR: $e');
      return false;
    }
  }

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
      debugPrint('Firestore getChildrenOfParent ERROR: $e');
      return [];
    }
  }

  // ============================================================
  // LINK CODES
  // ============================================================

  Future<String?> generateLinkCode({
    required String parentUid,
    required String parentName,
  }) async {
    try {
      final code = _generateCode();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      await _db.collection('link_codes').doc(code).set({
        'parentUid': parentUid,
        'parentName': parentName,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      return code;
    } catch (e) {
      debugPrint('Firestore generateLinkCode ERROR: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> validateLinkCode(String rawCode) async {
    try {
      final code = rawCode.trim().toUpperCase();
      final doc = await _db.collection('link_codes').doc(code).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt == null) return null;

      if (expiresAt.toDate().isBefore(DateTime.now())) return null;

      return {
        'code': doc.id,
        'parentUid': data['parentUid'],
        'parentName': data['parentName'],
        'expiresAt': expiresAt.toDate().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Firestore validateLinkCode ERROR: $e');
      return null;
    }
  }

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
      return true;
    } catch (e) {
      debugPrint('Firestore linkStudentToParent ERROR: $e');
      return false;
    }
  }

  Future<bool> unlinkStudentFromParent(String studentUid) async {
    try {
      await _db.collection('students').doc(studentUid).set({
        'parentId': FieldValue.delete(),
        'isLinked': FieldValue.delete(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Firestore unlinkStudentFromParent ERROR: $e');
      return false;
    }
  }

  Future<bool> deleteStudentCascade(String studentUid) async {
    try {
      final docRef = _db.collection('students').doc(studentUid);

      const subcollections = [
        'results',
        'badges',
        'mastery',
        'encounters',
        'starred',
      ];

      for (final sub in subcollections) {
        try {
          final snap = await docRef.collection(sub).get();
          for (final doc in snap.docs) {
            await doc.reference.delete();
          }
        } catch (e) {
          debugPrint('Firestore cascade delete failed for $sub: $e');
        }
      }

      await docRef.delete();
      return true;
    } catch (e) {
      debugPrint('Firestore deleteStudentCascade ERROR: $e');
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

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Firestore getStudentResultsFromCloud ERROR: $e');
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
      debugPrint('Firestore getStudentByUid ERROR: $e');
      try {
        final doc = await _db.collection('students').doc(studentUid).get();
        if (!doc.exists) return null;
        return {'uid': doc.id, ...doc.data()!};
      } catch (_) {
        return null;
      }
    }
  }

  // ============================================================
  // CLASSES
  // ============================================================

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

      final nestedRef = await _db
          .collection('teachers')
          .doc(teacherUid)
          .collection('classes')
          .add(payload);
      final classId = nestedRef.id;

      await _db.collection('classes').doc(classId).set({
        ...payload,
        'teacherUid': teacherUid,
        'teacherName': teacherName ?? '',
        'studentCount': 0,
      });

      return classId;
    } catch (e) {
      debugPrint('Firestore saveClassGroup ERROR: $e');
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
      debugPrint('Firestore getTeacherByUidFull ERROR: $e');
      return null;
    }
  }

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
      debugPrint('Firestore getClassesForTeacher ERROR: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getClassByJoinCode(String joinCode) async {
    try {
      final upperCode = joinCode.toUpperCase();

      final snapshot = await _db
          .collection('classes')
          .where('joinCode', isEqualTo: upperCode)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      final teacherUid = data['teacherUid'] as String? ?? '';

      return {
        'firestoreId': doc.id,
        'teacherUid': teacherUid,
        ...data,
      };
    } catch (e) {
      debugPrint('Firestore getClassByJoinCode ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // ENROLLMENTS
  // ============================================================

  Future<bool> enrollStudent({
    required String classId,
    required String studentUid,
    required String studentName,
    required int gradeLevel,
    int totalPoints = 0,
    int? avatarIndex,
  }) async {
    try {
      await _db
          .collection('classes')
          .doc(classId)
          .collection('enrollments')
          .doc(studentUid)
          .set({
        'studentName': studentName,
        'gradeLevel': gradeLevel,
        'totalPoints': totalPoints,
        'avatarIndex': avatarIndex ?? 1,
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('students').doc(studentUid).set({
        'classId': classId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('Firestore enrollStudent ERROR: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getEnrolledStudentsDetailed(
    String classId,
  ) async {
    try {
      final enrollments = await getEnrollmentsForClass(classId);

      if (enrollments.isEmpty) return [];

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
          'avatarIndex': (profile?['avatarIndex'] as int?) ?? (e['avatarIndex'] as int?) ?? 1,
          'enrolledAt': e['enrolledAt'],
        });
      }

      detailed.sort((a, b) =>
          (b['totalPoints'] as int).compareTo(a['totalPoints'] as int));

      return detailed;
    } catch (e) {
      debugPrint('Firestore getEnrolledStudentsDetailed ERROR: $e');
      return [];
    }
  }

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
      debugPrint('Firestore getEnrollmentsForClass ERROR: $e');
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
    int? avatarIndex,
  }) async {
    try {
      if (oldClassId.isNotEmpty && oldClassId != newClassId) {
        try {
          await _db
              .collection('classes')
              .doc(oldClassId)
              .collection('enrollments')
              .doc(studentUid)
              .delete();
        } catch (e) {
          debugPrint('Firestore: could not delete old enrollment: $e');
        }
        try {
          await _db.collection('classes').doc(oldClassId).update({
            'studentCount': FieldValue.increment(-1),
          });
        } catch (_) {}
      }

      try {
        await _db
            .collection('classes')
            .doc(newClassId)
            .collection('enrollments')
            .doc(studentUid)
            .set({
          'studentName': studentName,
          'gradeLevel': gradeLevel,
          'totalPoints': totalPoints,
          'avatarIndex': avatarIndex ?? 1,
          'enrolledAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore: FAILED to create enrollment: $e');
        return false;
      }

      try {
        await _db.collection('leaderboard').doc(studentUid).set({
          'displayName': studentName,
          'totalPoints': totalPoints,
          'gradeLevel': gradeLevel,
          'classId': newClassId,
          'avatarIndex': avatarIndex ?? 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore: leaderboard update failed: $e');
      }

      try {
        await _db.collection('students').doc(studentUid).set({
          'classId': newClassId,
          'displayName': studentName,
          'gradeLevel': gradeLevel,
          'totalPoints': totalPoints,
          'firebaseUid': studentUid,
          'avatarIndex': avatarIndex ?? 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore: FAILED to update student record: $e');
        return false;
      }

      try {
        await _db.collection('classes').doc(newClassId).update({
          'studentCount': FieldValue.increment(1),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Firestore transferStudent ERROR: $e');
      return false;
    }
  }

  Future<void> updateEnrollmentSnapshot({
    required String classId,
    required String studentUid,
    required int totalPoints,
    required int badgeCount,
    int? avatarIndex,
  }) async {
    try {
      final data = <String, dynamic>{
        'totalPoints': totalPoints,
        'badgeCount': badgeCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (avatarIndex != null) data['avatarIndex'] = avatarIndex;

      await _db
          .collection('classes')
          .doc(classId)
          .collection('enrollments')
          .doc(studentUid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updateEnrollmentSnapshot ERROR: $e');
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
    int? avatarIndex,
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
      if (avatarIndex != null) data['avatarIndex'] = avatarIndex;

      await _db.collection('leaderboard').doc(studentUid).set(
            data,
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Firestore updateLeaderboardEntry ERROR: $e');
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
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Firestore getGlobalLeaderboard ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getClassLeaderboard({
    required String classId,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _db
          .collection('leaderboard')
          .where('classId', isEqualTo: classId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      final entries = snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
      entries.sort((a, b) =>
          ((b['totalPoints'] ?? 0) as int)
              .compareTo((a['totalPoints'] ?? 0) as int));
      return entries;
    } catch (e) {
      debugPrint('Firestore getClassLeaderboard ERROR: $e');
      return [];
    }
  }

  // ============================================================
  // PROGRESS SYNC
  // ============================================================

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
      return true;
    } catch (e) {
      debugPrint('Firestore pushQuizAttempt ERROR: $e');
      return false;
    }
  }

  Future<void> syncStudentProgress(
    String studentUid,
    String studentName,
    int totalPoints,
    List<QuizResult> results,
  ) async {
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
    } catch (e) {
      debugPrint('Firestore syncStudentProgress ERROR: $e');
    }
  }

  Future<void> syncBadge({
    required String studentUid,
    required String badgeKey,
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
    } catch (e) {
      debugPrint('Firestore syncBadge ERROR: $e');
    }
  }

  // ============================================================
  // ATOMIC UPDATES
  // ============================================================

  Future<void> incrementStudentPoints(String studentUid, int delta) async {
    if (delta == 0) return;
    try {
      await _db.collection('students').doc(studentUid).set({
        'totalPoints': FieldValue.increment(delta),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore incrementStudentPoints ERROR: $e');
    }
  }

  // ============================================================
  // VERIFICATION MARKERS
  // ============================================================

  Future<void> markEmailVerified(String uid, String role) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'emailVerified': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore markEmailVerified ERROR: $e');
    }
  }

  Future<void> markPhoneVerified(String uid, String role) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'phoneVerified': true,
        'phoneVerifiedAt': DateTime.now().toIso8601String(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore markPhoneVerified ERROR: $e');
    }
  }

  Future<void> saveBackupCodeHash(String uid, String role, String hash) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'backupCodeHash': hash,
        'backupCodeUsed': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveBackupCodeHash ERROR: $e');
    }
  }

  Future<void> rotateBackupCode(String uid, String role, String newHash) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'backupCodeHash': newHash,
        'backupCodeUsed': false,
        'backupCodeRotatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore rotateBackupCode ERROR: $e');
    }
  }

  // ============================================================
  // WORD ANALYTICS SYNC
  // ============================================================

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
      debugPrint('Firestore syncWordMastery ERROR: $e');
    }
  }

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
      debugPrint('Firestore syncWordEncounter ERROR: $e');
    }
  }

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
      debugPrint('Firestore syncStarredWord ERROR: $e');
    }
  }

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
      debugPrint('Firestore unsyncStarredWord ERROR: $e');
    }
  }

  // ============================================================
  // WORD ANALYTICS PULL
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
      debugPrint('Firestore pullStudentMastery ERROR: $e');
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
      debugPrint('Firestore pullStudentEncounters ERROR: $e');
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
      debugPrint('Firestore pullStudentStarred ERROR: $e');
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
      debugPrint('Firestore pullStudentBadges ERROR: $e');
      return [];
    }
  }

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
      debugPrint('Firestore getParentByUidFull ERROR: $e');
      try {
        final doc = await _db.collection('parents').doc(parentUid).get();
        if (!doc.exists) return null;
        return {'uid': doc.id, ...doc.data()!};
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> markPhoneNumber(String uid, String role, String phoneNumber) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'phoneNumber': phoneNumber,
        'phoneVerified': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore markPhoneNumber ERROR: $e');
    }
  }

  Future<void> updatePhoneNumber({
    required String uid,
    required String role,
    required String phoneNumber,
    required bool verified,
  }) async {
    final collection = role == 'parent' ? 'parents' : 'teachers';
    try {
      await _db.collection(collection).doc(uid).set({
        'phoneNumber': phoneNumber,
        'phoneVerified': verified,
        if (verified) 'phoneVerifiedAt': DateTime.now().toIso8601String(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updatePhoneNumber ERROR: $e');
    }
  }
}