import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/badge.dart';
import '../../models/content_models.dart';
import '../../models/word.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../services/firestore_service.dart';

/// Runs a quiz for a single batch.
///
/// Reads from quiz_questions table. Supports literal / inferential /
/// critical question types. Saves responses + attempt + mastery.
class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({super.key});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  bool _loading = true;
  String? _error;

  // Data
  List<QuizQuestion> _questions = [];
  Map<int, Word> _wordsById = {};
  int _currentIndex = 0;
  List<String> _currentChoices = [];

  // State per question
  String? _selectedAnswer;
  bool _answered = false;
  DateTime? _questionStartTime;
  final List<int> _wrongWordIds = [];
  int _score = 0;
  final List<QuizQuestionResponse> _responses = [];

  // Batch info for saving
  int? _batchId;
  int? _studentId;
  int _gradeLevel = 1;
  String _difficulty = 'easy';

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuiz());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final batchId = args['batchId'] as int;
    final gradeLevel = (args['gradeLevel'] as int?) ?? 1;
    final difficulty = (args['difficulty'] as String?) ?? 'easy';
    final student = context.read<StudentProvider>().currentStudent;

    if (student == null || student.id == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    try {
      final questions =
          await DatabaseService.instance.getQuestionsForBatch(batchId);
      if (questions.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No quiz questions found.';
        });
        return;
      }

      final words = await DatabaseService.instance.getWordsInBatch(batchId);
      final wordMap = {for (final w in words) w.id!: w};

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _wordsById = wordMap;
        _batchId = batchId;
        _studentId = student.id;
        _gradeLevel = gradeLevel;
        _difficulty = difficulty;
        _loading = false;
        _questionStartTime = DateTime.now();
      });

      _loadCurrentChoices();
    } catch (e) {
      debugPrint('📝 QuizPlay ERROR: $e');
      setState(() {
        _loading = false;
        _error = 'Could not load quiz.';
      });
    }
  }

  void _loadCurrentChoices() {
    final q = _questions[_currentIndex];
    final choices = <String>[
      q.correctAnswer,
      ..._parseDistractors(q.distractorsJson),
    ];
    choices.shuffle();
    _currentChoices = choices;
  }

  List<String> _parseDistractors(String json) {
    final trimmed = json.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) return [];
    final inner = trimmed.substring(1, trimmed.length - 1);
    final matches = RegExp(r'"([^"]*)"').allMatches(inner);
    return matches.map((m) => m.group(1)!).toList();
  }

  Future<void> _playWordAudio(Word? word) async {
    if (word == null) return;
    try {
      final cleanPath = word.audioAsset.startsWith('assets/')
          ? word.audioAsset.substring('assets/'.length)
          : word.audioAsset;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(cleanPath));
    } catch (e) {
      debugPrint('🔊 Audio failed: $e');
    }
  }

  void _selectAnswer(String answer) {
    if (_answered) return;
    final q = _questions[_currentIndex];
    final isCorrect = answer == q.correctAnswer;

    final responseTime = _questionStartTime == null
        ? null
        : DateTime.now().difference(_questionStartTime!).inMilliseconds;

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (isCorrect) {
        _score++;
      } else {
        _wrongWordIds.add(q.wordId);
      }
      _responses.add(QuizQuestionResponse(
        attemptId: 0,
        questionId: q.id ?? 0,
        selectedAnswer: answer,
        isCorrect: isCorrect,
        responseTimeMs: responseTime,
      ));
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
        _questionStartTime = DateTime.now();
      });
      _loadCurrentChoices();
    } else {
      await _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    if (_studentId == null || _batchId == null) return;

    try {
      // 1. Compute points delta (best-score-per-batch rule)
      final pointsDelta =
          await DatabaseService.instance.computePointsDeltaForBatch(
        studentId: _studentId!,
        batchId: _batchId!,
        newScore: _score,
      );

      // 2. Save the attempt
      final attemptId = await DatabaseService.instance.saveQuizAttempt(
        QuizAttempt(
          studentId: _studentId!,
          batchId: _batchId!,
          score: _score,
          totalQuestions: _questions.length,
          pointsEarned: pointsDelta,
          wrongWordIdsJson: _wrongWordIds.isEmpty
              ? null
              : '[${_wrongWordIds.join(',')}]',
          completedAt: DateTime.now().toIso8601String(),
        ),
      );

      // 3. Save each question response
      for (final r in _responses) {
        await DatabaseService.instance.saveQuestionResponse(
          QuizQuestionResponse(
            attemptId: attemptId,
            questionId: r.questionId,
            selectedAnswer: r.selectedAnswer,
            isCorrect: r.isCorrect,
            responseTimeMs: r.responseTimeMs,
          ),
        );
      }

      // 4. Update word mastery + encounters
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final r = _responses[i];
        await DatabaseService.instance.recordWordEncounter(
          _studentId!,
          q.wordId,
        );
        await DatabaseService.instance.updateWordMastery(
          studentId: _studentId!,
          wordId: q.wordId,
          correct: r.isCorrect,
        );
      }

      // 5. Award points if improvement
      if (pointsDelta > 0) {
        await DatabaseService.instance.addPoints(_studentId!, pointsDelta);
      }

      // 6. Award badge if passing
      bool isNewBadge = false;
      final isPassing = _questions.isNotEmpty &&
          (_score / _questions.length) >= 0.70;
      if (isPassing) {
        final badgeName =
            AchievementBadge.nameFor(_gradeLevel, _difficulty);
        final badge = AchievementBadge(
          studentId: _studentId!,
          gradeLevel: _gradeLevel,
          difficulty: _difficulty,
          badgeName: badgeName,
          pointsEarned: pointsDelta,
          earnedAt: DateTime.now().toIso8601String(),
        );
        isNewBadge =
            await DatabaseService.instance.awardBadge(badge);
        debugPrint(
          isNewBadge
              ? '🏆 NEW badge: $badgeName'
              : '🏆 Already had: $badgeName',
        );
      }

      // 7. Refresh student in provider
      final updated =
          await DatabaseService.instance.getStudentById(_studentId!);
      if (!mounted) return;
      if (updated != null) {
        context.read<StudentProvider>().updateStudent(updated);

        // 7b. Compute badge count once (used in two places below)
        final badges = await DatabaseService.instance
            .getBadgesForStudent(updated.id!);

        // 7c. Sync student profile to Firestore (so parent sees fresh points)
        if (updated.firebaseUid != null) {
          try {
            await FirestoreService.instance.saveStudent(
              updated.firebaseUid!,
              updated.displayName,
              updated.gradeLevel,
              parentId: updated.parentId?.toString(),
              totalPoints: updated.totalPoints,
              badgeCount: badges.length,
            );
            debugPrint('🔥 Student profile synced to Firestore');
          } catch (e) {
            debugPrint('🔥 Student profile sync failed: $e');
          }
        }

        // 7d. If student is in a class, update their enrollment snapshot
        if (updated.classFirestoreId != null &&
            updated.classFirestoreId!.isNotEmpty &&
            updated.firebaseUid != null) {
          await FirestoreService.instance.updateEnrollmentSnapshot(
            classId: updated.classFirestoreId!,
            studentUid: updated.firebaseUid!,
            totalPoints: updated.totalPoints,
            badgeCount: badges.length,
          );
        }
      }

      if (!mounted) return;

      // 8. Navigate to Results screen
      Navigator.of(context).pushReplacementNamed(
        '/results',
        arguments: {
          'score': _score,
          'totalQuestions': _questions.length,
          'pointsDelta': pointsDelta,
          'gradeLevel': _gradeLevel,
          'difficulty': _difficulty,
          'isNewBadge': isNewBadge,
        },
      );
    } catch (e) {
      debugPrint('📝 QuizPlay finish ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save results. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError();
    }
    return _buildQuiz();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(_error!, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final q = _questions[_currentIndex];
    final word = _wordsById[q.wordId];
    final choices = _currentChoices;
    final isLast = _currentIndex == _questions.length - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Quiz', style: AppText.h2),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Progress
          Text(
            'Question ${_currentIndex + 1} of ${_questions.length}',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentTeal,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Question card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                if (q.showImage && word != null) ...[
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Image.asset(
                      word.imageAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.studentBg
                              .withValues(alpha: 0.6),
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 44,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                Text(
                  q.questionStem,
                  textAlign: TextAlign.center,
                  style: AppText.h2.copyWith(fontSize: 18),
                ),

                if (word != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  IconButton(
                    onPressed: () => _playWordAudio(word),
                    icon: const Icon(Icons.volume_up_rounded),
                    iconSize: 26,
                    color: AppColors.accentTeal,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AppColors.accentTeal.withValues(alpha: 0.15),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Answer choices
          ...choices.map((choice) {
            final isCorrect = choice == q.correctAnswer;
            final isSelected = choice == _selectedAnswer;

            Color bg = AppColors.surface;
            Color border = AppColors.border;
            IconData? icon;
            Color? iconColor;

            if (_answered) {
              if (isCorrect) {
                bg = AppColors.accentTeal.withValues(alpha: 0.15);
                border = AppColors.accentTeal;
                icon = Icons.check_circle_rounded;
                iconColor = AppColors.accentTeal;
              } else if (isSelected) {
                bg = AppColors.accentCoral.withValues(alpha: 0.15);
                border = AppColors.accentCoral;
                icon = Icons.cancel_rounded;
                iconColor = AppColors.accentCoral;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InkWell(
                onTap: () => _selectAnswer(choice),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          choice,
                          style: AppText.bodyBold.copyWith(fontSize: 16),
                        ),
                      ),
                      if (icon != null)
                        Icon(icon, color: iconColor),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.md),

          // Next button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _answered ? _nextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast
                    ? AppColors.accentYellow
                    : AppColors.accentTeal,
                foregroundColor: isLast
                    ? AppColors.textPrimary
                    : Colors.white,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
              child: Text(
                isLast ? 'Finish' : 'Next Question',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}