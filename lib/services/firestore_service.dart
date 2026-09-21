import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teacher.dart';
import '../models/class_group.dart';
import 'package:flutter/foundation.dart';
import '../models/quiz_result.dart';
import 'dart:async';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._internal();
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- Teacher ----------

  Future<void> saveTeacher(Teacher teacher, String firebaseUid) async {
    await _db.collection('teachers').doc(firebaseUid).set({
      'username': teacher.username,
      'fullName': teacher.fullName,
      'email': teacher.email,
      'schoolName': teacher.schoolName,
      'createdAt': teacher.createdAt,
    });
  }

  Future<Map<String, dynamic>?> getTeacherByUid(
      String firebaseUid) async {
    final doc =
        await _db.collection('teachers').doc(firebaseUid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // ---------- Class Groups ----------

  Future<String> saveClassGroup(
      ClassGroup group, String teacherUid) async {
    final ref = await _db
        .collection('teachers')
        .doc(teacherUid)
        .collection('classes')
        .add({
      'className': group.className,
      'gradeLevel': group.gradeLevel,
      'joinCode': group.joinCode,
      'createdAt': group.createdAt,
    });
    return ref.id;
  }

  Future<List<Map<String, dynamic>>> getClassesForTeacher(
      String teacherUid) async {
    final snapshot = await _db
        .collection('teachers')
        .doc(teacherUid)
        .collection('classes')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => {'firestoreId': doc.id, ...doc.data()})
        .toList();
  }

  Future<Map<String, dynamic>?> getClassByJoinCode(
      String joinCode) async {
    final snapshot = await _db
        .collectionGroup('classes')
        .where('joinCode', isEqualTo: joinCode)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return {'firestoreId': doc.id, ...doc.data()};
  }

  // ---------- Enrollments ----------

  Future<void> enrollStudent(
      String classFirestoreId,
      String teacherUid,
      String studentUid,
      String studentName,
      int gradeLevel) async {
    await _db
        .collection('teachers')
        .doc(teacherUid)
        .collection('classes')
        .doc(classFirestoreId)
        .collection('enrollments')
        .doc(studentUid)
        .set({
      'studentName': studentName,
      'gradeLevel': gradeLevel,
      'enrolledAt': DateTime.now().toIso8601String(),
    });
  }

  // ---------- Progress Sync ----------

  Future<void> syncStudentProgress(
      String studentUid,
      String studentName,
      int totalPoints,
      List<QuizResult> results) async {
    final data = {
      'studentName': studentName,
      'totalPoints': totalPoints,
      'lastSynced': DateTime.now().toIso8601String(),
      'results': results
          .map((r) => {
                'gradeLevel': r.gradeLevel,
                'difficulty': r.difficulty,
                'score': r.score,
                'totalQuestions': r.totalQuestions,
                'pointsEarned': r.pointsEarned,
                'isPassing': r.isPassing,
                'completedAt': r.completedAt,
              })
          .toList(),
    };
    await _db
        .collection('students')
        .doc(studentUid)
        .set(data, SetOptions(merge: true));
  }

  // ---------- Global Leaderboard ----------

  Future<void> updateLeaderboardEntry(
    String studentUid,
    String displayName,
    int totalPoints,
    int gradeLevel,
    int badgeCount,
  ) async {
    try {
      await _db.collection('leaderboard').doc(studentUid).set({
        'displayName': displayName,
        'totalPoints': totalPoints,
        'gradeLevel': gradeLevel,
        'badgeCount': badgeCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updateLeaderboardEntry error: $e');
    }
  }

  /// Fetch top global rankings sorted by total points.
  /// Uses Firestore's native orderBy + limit — no client-side sort.
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
      debugPrint('Firestore getGlobalLeaderboard error: $e');
      return [];
    }
  }

  /// Fetch class leaderboard for a specific class.
  /// Requires composite index on (classFirestoreId, totalPoints).
  /// Will be used once class enrollment is implemented in M4.
  Future<List<Map<String, dynamic>>> getClassLeaderboard(
    String classFirestoreId, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _db
          .collection('leaderboard')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .orderBy('totalPoints', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Firestore getClassLeaderboard error: $e');
      return [];
    }
  }
}