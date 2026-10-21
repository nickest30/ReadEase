import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/badge.dart';
import '../../models/content_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../services/bgm_service.dart';
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';
import 'yse_reaction.dart';
import '../../widgets/info_button.dart';

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  bool _loading = true;
  String? _error;

  List<_MemoryCard> _cards = [];
  Map<int, QuizQuestion> _questionByWordId = {};

  int _batchId = 0;
  int _studentId = 0;
  int _gradeLevel = 1;
  String _difficulty = 'easy';

  final List<int> _flippedIndices = [];
  final Set<int> _correctPairIds = {};
  final Set<int> _allPairIds = {};
  final Set<String> _failedCombos = {};
  bool _locked = false;

  final YseReactionController _reaction = YseReactionController();
  int _currentStreak = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    BgmService.playTrack(BgmTrack.game);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGame());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _reaction.dispose();
    super.dispose();
  }

  Future<void> _loadGame() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/student-home', (route) => false);
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
      final words = await DatabaseService.instance.getSampledWordsForBatch(batchId);
      if (words.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No words found for this game.';
        });
        return;
      }

      final limited = words.toList();

      final questions = await DatabaseService.instance.getQuestionsForBatch(batchId);
      final qMap = <int, QuizQuestion>{};
      for (final q in questions) {
        qMap.putIfAbsent(q.wordId, () => q);
      }

      final deck = <_MemoryCard>[];
      for (final w in limited) {
        deck.add(_MemoryCard(
          pairId: w.id!,
          wordText: w.text,
          imagePath: w.imageAsset,
          audioPath: w.audioAsset,
          isWordCard: true,
        ));
        deck.add(_MemoryCard(
          pairId: w.id!,
          wordText: w.text,
          imagePath: w.imageAsset,
          audioPath: w.audioAsset,
          isWordCard: false,
        ));
      }
      deck.shuffle(Random());
      for (var i = 0; i < deck.length; i++) {
        deck[i].id = i;
      }

      if (!mounted) return;
      setState(() {
        _cards = deck;
        _questionByWordId = qMap;
        _batchId = batchId;
        _studentId = student.id!;
        _gradeLevel = gradeLevel;
        _difficulty = difficulty;
        _allPairIds.addAll(limited.map((w) => w.id!));
        _loading = false;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _reaction.show(YseReaction.letsGo, persistent: true);
    } catch (e) {
      debugPrint('MemoryMatch load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load game. Try again.';
      });
    }
  }

  Future<void> _onCardTap(int index) async {
    if (_locked) return;
    final card = _cards[index];
    if (card.isMatched || card.isFlipped || _flippedIndices.contains(index)) return;

    SfxService.tap();

    setState(() {
      card.isFlipped = true;
      _flippedIndices.add(index);
    });

    _playWordAudio(card.audioPath);

    if (_flippedIndices.length < 2) return;

    _locked = true;
    final a = _cards[_flippedIndices[0]];
    final b = _cards[_flippedIndices[1]];

    final isMatch = a.pairId == b.pairId && a.isWordCard != b.isWordCard;

    if (isMatch) {
      final combo = _comboKey(a.id, b.id);
      final isFirstAttempt = !_failedCombos.contains(combo);

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      setState(() {
        a.isMatched = true;
        b.isMatched = true;
        _flippedIndices.clear();
        _locked = false;
        if (isFirstAttempt) _correctPairIds.add(a.pairId);
      });

      SfxService.correct();

      if (isFirstAttempt) {
        _currentStreak++;
        if (_currentStreak >= 3) {
          _reaction.show(YseReaction.hwaiting, persistent: true);
        } else {
          _reaction.show(YseReaction.nice, persistent: true);
        }
      }

      if (_cards.every((c) => c.isMatched)) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) await _finishGame();
      }
    } else {
      _failedCombos.add(_comboKey(a.id, b.id));
      _currentStreak = 0;

      SfxService.wrong();
      _reaction.show(YseReaction.tryAgain, persistent: true);

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      setState(() {
        a.isFlipped = false;
        b.isFlipped = false;
        _flippedIndices.clear();
        _locked = false;
      });
    }
  }

  String _comboKey(int id1, int id2) {
    final a = id1 < id2 ? id1 : id2;
    final b = id1 < id2 ? id2 : id1;
    return '$a-$b';
  }

  Future<void> _playWordAudio(String assetPath) async {
    try {
      final clean = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(clean));
    } catch (e) {
      debugPrint('Word audio failed: $e');
    }
  }

  Future<void> _finishGame() async {
    final correctCount = _correctPairIds.length;
    final wrongPairIds = _allPairIds.difference(_correctPairIds).toList();
    final isPassing = _allPairIds.isNotEmpty && (correctCount / _allPairIds.length) >= 0.70;

    try {
      if (isPassing) {
        _reaction.show(YseReaction.youDidIt, persistent: true);
        SfxService.celebration();
        await Future.delayed(const Duration(milliseconds: 1500));
      } else {
        _reaction.show(YseReaction.tryAgain, persistent: true);
        SfxService.fail();
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      
      if (!mounted) return;

      final pointsDelta = await DatabaseService.instance.computePointsDeltaForBatch(
        studentId: _studentId,
        batchId: _batchId,
        newScore: correctCount,
      );

      final attemptId = await DatabaseService.instance.saveQuizAttempt(
        QuizAttempt(
          studentId: _studentId,
          batchId: _batchId,
          score: correctCount,
          totalQuestions: _allPairIds.length,
          pointsEarned: pointsDelta,
          wrongWordIdsJson: wrongPairIds.isEmpty ? null : '[${wrongPairIds.join(',')}]',
          completedAt: DateTime.now().toIso8601String(),
        ),
      );

      for (final wordId in _allPairIds) {
        final q = _questionByWordId[wordId];
        if (q == null) continue;
        final wasCorrect = _correctPairIds.contains(wordId);
        await DatabaseService.instance.saveQuestionResponse(
          QuizQuestionResponse(
            attemptId: attemptId,
            questionId: q.id ?? 0,
            selectedAnswer: wasCorrect ? 'first_attempt_match' : 'delayed_match',
            isCorrect: wasCorrect,
            responseTimeMs: null,
          ),
        );
      }

      for (final wordId in _allPairIds) {
        await DatabaseService.instance.recordWordEncounter(_studentId, wordId);
        await DatabaseService.instance.updateWordMastery(
          studentId: _studentId,
          wordId: wordId,
          correct: _correctPairIds.contains(wordId),
        );
      }

      if (pointsDelta > 0) {
        await DatabaseService.instance.addPoints(_studentId, pointsDelta);
      }

      bool isNewBadge = false;
      if (isPassing) {
        final badgeName = AchievementBadge.nameFor(_gradeLevel, _difficulty);
        final badge = AchievementBadge(
          studentId: _studentId,
          gradeLevel: _gradeLevel,
          difficulty: _difficulty,
          badgeName: badgeName,
          pointsEarned: pointsDelta,
          earnedAt: DateTime.now().toIso8601String(),
        );
        isNewBadge = await DatabaseService.instance.awardBadge(badge);
      }

      final updated = await DatabaseService.instance.getStudentById(_studentId);
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
              final badges = await DatabaseService.instance.getBadgesForStudent(updated.id!);
              await FirestoreService.instance.updateEnrollmentSnapshot(
                classId: updated.classFirestoreId!,
                studentUid: updated.firebaseUid!,
                totalPoints: updated.totalPoints,
                badgeCount: badges.length,
                avatarIndex: updated.avatarIndex,
              );
            } catch (e) {
              debugPrint('Enrollment snapshot failed: $e');
            }
          }());
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '/results',
        arguments: {
          'score': correctCount,
          'totalQuestions': _allPairIds.length,
          'pointsDelta': pointsDelta,
          'gradeLevel': _gradeLevel,
          'difficulty': _difficulty,
          'isNewBadge': isNewBadge,
        },
      );
    } catch (e) {
      debugPrint('MemoryMatch finish ERROR: $e');
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    return _buildGame();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.textMuted),
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

  Widget _buildGame() {
    final matchedPairs = _cards.where((c) => c.isMatched).length ~/ 2;
    final totalPairs = _allPairIds.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          children: [
            _buildHeader(matchedPairs, totalPairs),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildGrid()),
            Container(
              height: 100,
              alignment: Alignment.center,
              child: YseReactionOverlay(
                controller: _reaction,
                size: 100,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int matchedPairs, int totalPairs) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Match the Word', style: AppText.h2),
                    const InfoButton(
                      title: 'How to Match',
                      description: 'Find the matching pairs of words and pictures.',
                      steps: [
                        'Tap a card to flip it over.',
                        'Tap a second card to find its match.',
                        'If they match, they stay face up!',
                        'If they don\'t match, they will flip back over.',
                        'Match all the pairs to win!',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 20, color: AppColors.accentYellow),
                    const SizedBox(width: 6),
                    Text(
                      '${_correctPairIds.length * 5} pts',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textYellow),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.accentTeal),
                    const SizedBox(width: 6),
                    Text(
                      '$matchedPairs / $totalPairs pairs',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTeal),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _cards.length <= 12 ? 3 : (_cards.length <= 20 ? 4 : 5);
        final rows = (_cards.length / columns).ceil();

        const spacing = 10.0;
        const outerPadding = 16.0;

        final availableHeight = constraints.maxHeight - (rows - 1) * spacing;
        final cardHeight = availableHeight / rows;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: outerPadding),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: cardHeight,
            ),
            itemCount: _cards.length,
            itemBuilder: (context, index) {
              return _MemoryCardTile(
                card: _cards[index],
                onTap: () => _onCardTap(index),
              );
            },
          ),
        );
      },
    );
  }
}

class _MemoryCard {
  int id = 0;
  final int pairId;
  final String wordText;
  final String imagePath;
  final String audioPath;
  final bool isWordCard;

  bool isFlipped = false;
  bool isMatched = false;

  _MemoryCard({
    required this.pairId,
    required this.wordText,
    required this.imagePath,
    required this.audioPath,
    required this.isWordCard,
  });
}

class _MemoryCardTile extends StatelessWidget {
  final _MemoryCard card;
  final VoidCallback onTap;

  const _MemoryCardTile({
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showFace = card.isFlipped || card.isMatched;
    final borderColor = card.isMatched
        ? AppColors.accentGreen
        : (card.isFlipped ? AppColors.accentTeal : AppColors.border);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: showFace ? AppColors.surface : AppColors.accentTeal,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: card.isMatched
              ? [BoxShadow(color: AppColors.accentGreen.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 1)]
              : AppShadows.soft,
        ),
        child: Center(
          child: showFace ? _buildFace() : _buildBack(),
        ),
      ),
    );
  }

  Widget _buildBack() {
    return const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 36);
  }

  Widget _buildFace() {
    if (card.isWordCard) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            card.wordText,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset(
        card.imagePath,
        fit: BoxFit.contain,
        cacheWidth: 200,
        errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 32, color: AppColors.textMuted),
      ),
    );
  }
}