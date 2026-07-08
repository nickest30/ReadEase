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
      String studentUid, String displayName, int totalPoints,
      int gradeLevel) async {
    await _db.collection('leaderboard').doc(studentUid).set({
      'displayName': displayName,
      'totalPoints': totalPoints,
      'gradeLevel': gradeLevel,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getGlobalLeaderboard() async {
    try {
      debugPrint('Firestore: attempting global leaderboard query...');
      final snapshot = await _db
          .collection('leaderboard')
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 10));
      debugPrint('Firestore: got ${snapshot.docs.length} entries');
      final entries = snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
      // Sort in Dart instead of Firestore to avoid index requirement
      entries.sort((a, b) =>
          (b['totalPoints'] as int).compareTo(a['totalPoints'] as int));
      return entries;
    } catch (e) {
      debugPrint('Firestore leaderboard error: $e');
      return [];
    }
  }
}