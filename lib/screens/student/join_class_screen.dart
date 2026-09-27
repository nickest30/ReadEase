import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/connectivity_provider.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _foundClass;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchClass() async {
    // Fast-fail when offline
    if (!context.read<ConnectivityProvider>().isOnline) {
      setState(() {
        _errorMessage = 'You\'re offline. Join Class needs internet.';
        _foundClass = null;
      });
      return;
    }

    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Join code must be 6 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _foundClass = null;
    });

    final result = await FirestoreService.instance.getClassByJoinCode(code);

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      if (result == null) {
        _errorMessage =
            'No class found with that code.\nAsk your teacher to double-check.';
        _foundClass = null;
      } else {
        _foundClass = result;
        _errorMessage = null;
      }
    });
  }

  Future<void> _confirmJoin() async {
    if (_foundClass == null) return;

    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) return;

    if (student.firebaseUid == null) {
      setState(() {
        _errorMessage =
            'Please connect to the internet and log in with your full credentials to join a class.';
      });
      return;
    }

    // ── Warn if switching classes ──
    final alreadyInClass = student.classFirestoreId != null &&
        student.classFirestoreId!.isNotEmpty;

    if (alreadyInClass) {
      final newClassName = _foundClass!['className'] as String;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          backgroundColor: AppColors.surface,
          title: const Text(
            'Switch Class?',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Text(
            'You\'re currently in "${student.className}".\n\n'
            'Join "$newClassName" and leave the old one?',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: AppColors.textMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Switch',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final classFirestoreId = _foundClass!['firestoreId'] as String;
    final className = _foundClass!['className'] as String;

    debugPrint('🔑 DEBUG student.firebaseUid = ${student.firebaseUid}');
    debugPrint('🔑 DEBUG current auth uid    = ${FirebaseAuth.instance.currentUser?.uid}');

    // 1. Enroll in Firestore
    final enrolled = await FirestoreService.instance.transferStudent(
      oldClassId: student.classFirestoreId ?? '',
      newClassId: classFirestoreId,
      studentUid: student.firebaseUid!,
      studentName: student.displayName,
      gradeLevel: student.gradeLevel,
      totalPoints: student.totalPoints,
    );

    if (!mounted) return;

    if (!enrolled) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'Could not join the class. Check your internet and try again.';
      });
      return;
    }

    // 2. Save locally
    await DatabaseService.instance.updateStudentClass(
      student.id!,
      classFirestoreId,
      className,
    );

    if (!mounted) return;

    // 3. Refresh student in provider
    final refreshed =
        await DatabaseService.instance.getStudentById(student.id!);
    if (!mounted || refreshed == null) return;

    context.read<StudentProvider>().updateStudent(refreshed);

    // 4. Show success
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.accentTeal,
              size: 28,
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Joined!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'You joined $className.\nYour scores will now appear in the class leaderboard!',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Great!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;

    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final isAlreadyJoined = student.classFirestoreId != null;

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Header with Yse
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Join Class', style: AppText.h1),
                        SizedBox(height: 2),
                        Text(
                          'Enter your teacher\'s code',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/mascot/yse_peek.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentTeal,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.group_add_rounded,
                        color: AppColors.accentTeal,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // If already joined, show current class
              if (isAlreadyJoined)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(
                      color: AppColors.accentTeal,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.class_rounded,
                        color: AppColors.accentTeal,
                        size: 32,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Currently in:',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              student.className ?? 'Class',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.textTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (isAlreadyJoined) const SizedBox(height: AppSpacing.lg),

              // Instruction
              if (!isAlreadyJoined)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.accentTeal,
                        size: 32,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Ask your teacher for the 6-character join code.',
                        textAlign: TextAlign.center,
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              // Code input
              const Text(
                'Join Code',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  hintStyle: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide:
                        const BorderSide(color: AppColors.accentTeal, width: 2),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textCoral,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Search button
              if (_foundClass == null)
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _searchClass,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text(
                      'FIND CLASS',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                  ),
                ),

              // Found class — show details + confirm
              if (_foundClass != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(
                      color: AppColors.accentTeal,
                      width: 2,
                    ),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        color: AppColors.accentTeal,
                        size: 40,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _foundClass!['className'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Grade ${_foundClass!['gradeLevel']}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _confirmJoin,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      'JOIN THIS CLASS',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _foundClass = null;
                      _codeController.clear();
                    });
                  },
                  child: const Text(
                    'Try a different code',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}