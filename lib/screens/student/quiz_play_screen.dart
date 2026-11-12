import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/badge.dart';
import '../../models/content_models.dart';
import '../../models/word.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../services/bgm_service.dart';
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/info_button.dart';

class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({super.key});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  bool _loading = true;
  String? _error;

  List<QuizQuestion> _questions = [];
  Map<int, Word> _wordsById = {};
  int _currentIndex = 0;
  List<String> _currentChoices = [];

  String? _selectedAnswer;
  bool _answered = false;
  DateTime? _questionStartTime;
  final List<int> _wrongWordIds = [];
  int _score = 0;
  final List<QuizQuestionResponse> _responses = [];

  int? _batchId;
  int? _studentId;
  int _gradeLevel = 1;
  String _difficulty = 'easy';

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    BgmService.playTrack(BgmTrack.game);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuiz());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/student-home', (route) => false);
        }
      });
      return;
    }

    final batchId = args['batchId'] as int?;
    final gradeLevel = (args['gradeLevel'] as int?) ?? 1;
    final difficulty = (args['difficulty'] as String?) ?? 'easy';
    final student = context.read<StudentProvider>().currentStudent;

    if (batchId == null || student == null || student.id == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in or missing data.';
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

      final words =
          await DatabaseService.instance.getSampledWordsForBatch(batchId);
      final wordMap = {for (final w in words) w.id!: w};

      if (!mounted) return;

      final sampledIds = words.map((w) => w.id).toSet();
      final sampledQuestions =
          questions.where((q) => sampledIds.contains(q.wordId)).toList();

      setState(() {
        _questions = sampledQuestions;
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
      debugPrint('QuizPlay ERROR: $e');
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
      debugPrint('Audio failed: $e');
    }
  }

  void _selectAnswer(String answer) {
    if (_answered) return;
    final q = _questions[_currentIndex];
    final isCorrect = answer == q.correctAnswer;

    if (isCorrect) {
      SfxService.correct();
    } else {
      SfxService.wrong();
    }

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

    int pointsDelta = 0;
    bool isNewBadge = false;
    bool localSaveSucceeded = false;

    try {
      pointsDelta = await DatabaseService.instance.computePointsDeltaForBatch(
        studentId: _studentId!,
        batchId: _batchId!,
        newScore: _score,
      );

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

      final responseCount = _responses.length < _questions.length
          ? _responses.length
          : _questions.length;
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final isCorrectResponse =
            i < responseCount ? _responses[i].isCorrect : false;
        await DatabaseService.instance.recordWordEncounter(_studentId!, q.wordId);
        await DatabaseService.instance.updateWordMastery(
          studentId: _studentId!,
          wordId: q.wordId,
          correct: isCorrectResponse,
        );
      }

      if (pointsDelta > 0) {
        await DatabaseService.instance.addPoints(_studentId!, pointsDelta);
      }

      final isPassing =
          _questions.isNotEmpty && (_score / _questions.length) >= 0.70;
      if (isPassing) {
        final badgeName = AchievementBadge.nameFor(_gradeLevel, _difficulty);
        final badge = AchievementBadge(
          studentId: _studentId!,
          gradeLevel: _gradeLevel,
          difficulty: _difficulty,
          badgeName: badgeName,
          pointsEarned: pointsDelta,
          earnedAt: DateTime.now().toIso8601String(),
        );
        isNewBadge = await DatabaseService.instance.awardBadge(badge);
      }

      localSaveSucceeded = true;
    } catch (e) {
      debugPrint('QuizPlay local save ERROR: $e');
    }

    if (!localSaveSucceeded) {
      if (!mounted) return;
      final retry = await _showSaveErrorDialog();
      if (!mounted) return;
      if (retry == true) {
        await _finishQuiz();
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/student-home',
          (route) => false,
        );
      }
      return;
    }

    final updated = await DatabaseService.instance.getStudentById(_studentId!);
    if (!mounted) return;

    if (updated != null) {
      context.read<StudentProvider>().setStudent(updated);

      final connectivity = context.read<ConnectivityProvider>();
      final authProvider = context.read<AuthProvider>();

      unawaited(
        SyncService.instance.syncAll(
          student: updated,
          connectivity: connectivity,
          authProvider: authProvider,
        ),
      );

      if (updated.classFirestoreId != null &&
          updated.classFirestoreId!.isNotEmpty &&
          updated.firebaseUid != null) {
        unawaited(() async {
          try {
            final badges = await DatabaseService.instance
                .getBadgesForStudent(updated.id!);
            await FirestoreService.instance.updateEnrollmentSnapshot(
              classId: updated.classFirestoreId!,
              studentUid: updated.firebaseUid!,
              totalPoints: updated.totalPoints,
              badgeCount: badges.length,
              avatarIndex: updated.avatarIndex,
            );
          } catch (e) {
            debugPrint('Enrollment snapshot update failed: $e');
          }
        }());
      }
    }

    if (!mounted) return;

    final isPassing =
        _questions.isNotEmpty && (_score / _questions.length) >= 0.70;
    if (isPassing) {
      SfxService.celebration();
    } else {
      SfxService.fail();
    }
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

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
  }

  Future<bool?> _showSaveErrorDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.accentOrange, size: 26),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Could not save your score',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your score was not saved on this device. Would you like to try again?',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop(false);
            },
            child: const Text(
              'Go Home',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(_error!, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: Responsive.buttonHeight(context),
              child: ElevatedButton(
                onPressed: () {
                  SfxService.tap();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Go Back',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
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
    final isTablet = Responsive.isTablet(context);
    final imgSize = Responsive.imageSize(context, base: 140);
    final buttonHeight = Responsive.buttonHeight(context);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              IconButton(
                onPressed: () {
                  SfxService.tap();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quiz', style: AppText.h2),
                    const InfoButton(
                      title: 'How to Play',
                      description:
                          'Answer the questions to finish the lesson.',
                      steps: [
                        'Read the question and look at the picture.',
                        'Tap the speaker icon to hear the word.',
                        'Tap the correct answer.',
                        'Tap Next Question to continue.',
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

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
                    width: imgSize,
                    height: imgSize,
                    child: Image.asset(
                      word.imageAsset,
                      fit: BoxFit.contain,
                      cacheWidth: (imgSize * 2).toInt(),
                      errorBuilder: (_, _, _) => Container(
                        width: imgSize,
                        height: imgSize,
                        decoration: BoxDecoration(
                          color: AppColors.studentBg.withValues(alpha: 0.6),
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: imgSize * 0.32,
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
                    onPressed: () {
                      SfxService.tap();
                      _playWordAudio(word);
                    },
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
                onTap: _answered ? null : () => _selectAnswer(choice),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            choice,
                            style: AppText.bodyBold.copyWith(fontSize: 16),
                          ),
                        ),
                      ),
                      if (icon != null) Icon(icon, color: iconColor),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.md),

          SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: _answered
                  ? () {
                      SfxService.tap();
                      _nextQuestion();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast
                    ? AppColors.accentYellow
                    : AppColors.accentTeal,
                foregroundColor: isLast
                    ? AppColors.textPrimary
                    : Colors.white,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isLast ? 'Finish' : 'Next Question',
                  style: const TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: content,
        ),
      );
    }

    return content;
  }
}