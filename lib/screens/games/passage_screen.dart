import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../models/content_models.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

/// PassageScreen — simplified version (Grade 4+).
///
/// Flow:
///   1. Show illustration + title
///   2. Play sentences one by one (active sentence highlighted)
///   3. After last sentence, show comprehension questions
///   4. Compute passage score, pass to game via route args
class PassageScreen extends StatefulWidget {
  const PassageScreen({super.key});

  @override
  State<PassageScreen> createState() => _PassageScreenState();
}

enum _PassagePhase { loading, reading, questions, done }

class _PassageScreenState extends State<PassageScreen> {
  _PassagePhase _phase = _PassagePhase.loading;
  String? _error;

  Passage? _passage;
  List<PassageSentence> _sentences = [];
  List<PassageQuestion> _questions = [];

  int _activeSentenceIndex = 0;
  bool _isPlaying = false;

  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool _answered = false;
  int _passageCorrect = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPassage());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadPassage() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final passageKey = args['passageId'] as String?;

    if (passageKey == null || passageKey.isEmpty) {
      // No passage — skip straight to game intro.
      Navigator.of(context).pushReplacementNamed(
        '/game-intro',
        arguments: args,
      );
      return;
    }

    final passage = await DatabaseService.instance
        .getPassageByKey(passageKey);

    if (passage == null || passage.id == null) {
      setState(() {
        _phase = _PassagePhase.loading;
        _error = 'Passage not found.';
      });
      return;
    }

    final sentences = await DatabaseService.instance
        .getSentencesForPassage(passage.id!);
    final questions = await DatabaseService.instance
        .getQuestionsForPassage(passage.id!);

    if (!mounted) return;

    setState(() {
      _passage = passage;
      _sentences = sentences;
      _questions = questions;
      _phase = _PassagePhase.reading;
      _activeSentenceIndex = 0;
    });
  }

  Future<void> _playSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    final sentence = _sentences[index];

    setState(() {
      _activeSentenceIndex = index;
      _isPlaying = true;
    });

    try {
      final clean = sentence.audio.startsWith('assets/')
          ? sentence.audio.substring('assets/'.length)
          : sentence.audio;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(clean));
      // Wait for completion or 15s timeout.
      await _audioPlayer.onPlayerComplete
          .first
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('🔊 Sentence audio failed (continuing): $e');
    }

    if (!mounted) return;
    setState(() => _isPlaying = false);
  }

  Future<void> _onNextSentence() async {
    if (_isPlaying) return;

    if (_activeSentenceIndex < _sentences.length - 1) {
      await _playSentence(_activeSentenceIndex + 1);
    } else {
      // Last sentence — move to questions.
      setState(() => _phase = _PassagePhase.questions);
    }
  }

  void _onSelectAnswer(String answer) {
    if (_answered) return;
    final q = _questions[_currentQuestionIndex];
    final isCorrect = answer == q.correctAnswer;

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (isCorrect) _passageCorrect++;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _answered = false;
        });
      } else {
        setState(() => _phase = _PassagePhase.done);
        _navigateToGame();
      }
    });
  }

  void _navigateToGame() {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    Navigator.of(context).pushReplacementNamed(
      '/game-intro',
      arguments: {
        'batchId': args['batchId'],
        'gradeLevel': args['gradeLevel'],
        'difficulty': args['difficulty'],
        'gameType': args['gameType'],
        'passageCorrect': _passageCorrect,
        'passageTotal': _questions.length,
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _buildError();
    switch (_phase) {
      case _PassagePhase.loading:
        return const Center(child: CircularProgressIndicator());
      case _PassagePhase.reading:
        return _buildReading();
      case _PassagePhase.questions:
        return _buildQuestions();
      case _PassagePhase.done:
        return const Center(child: CircularProgressIndicator());
    }
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

  // ────────────────────────────────────────────────────────────
  // Reading phase
  // ────────────────────────────────────────────────────────────

  Widget _buildReading() {
    final p = _passage!;
    final screenH = MediaQuery.of(context).size.height;
    final illustrationSize = (screenH * 0.28).clamp(180.0, 240.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),

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
                child: Text('Read the Passage', style: AppText.h2),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Illustration
          Container(
            width: illustrationSize,
            height: illustrationSize,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border, width: 2),
              boxShadow: AppShadows.soft,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              p.illustration,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_outlined,
                size: 72,
                color: AppColors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            p.title,
            textAlign: TextAlign.center,
            style: AppText.h2.copyWith(fontSize: 18),
          ),

          const SizedBox(height: AppSpacing.md),

          // Sentences
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(_sentences.length, (i) {
                  final s = _sentences[i];
                  final isActive = i == _activeSentenceIndex;
                  final isDone = i < _activeSentenceIndex;

                  return GestureDetector(
                    onTap: isDone ? () => _playSentence(i) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.accentYellow
                                .withValues(alpha: 0.25)
                            : AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accentYellow
                              : AppColors.border,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        s.text,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          height: 1.5,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isDone
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Next button
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPlaying ? null : _onNextSentence,
              icon: Icon(
                _activeSentenceIndex >= _sentences.length - 1
                    ? Icons.quiz_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(
                _activeSentenceIndex >= _sentences.length - 1
                    ? 'ASK QUESTIONS'
                    : 'NEXT SENTENCE',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
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

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Questions phase
  // ────────────────────────────────────────────────────────────

  Widget _buildQuestions() {
    final q = _questions[_currentQuestionIndex];
    final distractors = _parseDistractors(q.distractorsJson);
    final choices = <String>[q.correctAnswer, ...distractors]..shuffle(Random());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              const Expanded(
                child: Text('Comprehension', style: AppText.h2),
              ),
              Text(
                'Q ${_currentQuestionIndex + 1} / ${_questions.length}',
                style: AppText.caption,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentTeal,
              ),
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
            child: Text(
              q.stem,
              textAlign: TextAlign.center,
              style: AppText.h2.copyWith(fontSize: 18),
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
                onTap: _answered ? null : () => _onSelectAnswer(choice),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          choice,
                          style: AppText.bodyBold.copyWith(fontSize: 15),
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

          const Spacer(),
        ],
      ),
    );
  }

  List<String> _parseDistractors(String json) {
    try {
      final decoded = json.trim();
      if (!decoded.startsWith('[') || !decoded.endsWith(']')) return [];
      final inner = decoded.substring(1, decoded.length - 1);
      final matches = RegExp(r'"([^"]*)"').allMatches(inner);
      return matches.map((m) => m.group(1)!).toList();
    } catch (_) {
      return [];
    }
  }
}