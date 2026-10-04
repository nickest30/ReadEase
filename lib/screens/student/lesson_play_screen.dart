import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/content_models.dart';
import '../../models/word.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

/// Orchestrates the full lesson flow for a single batch:
/// Opening Frame (first visit only) → Introduce → Quiz
class LessonPlayScreen extends StatefulWidget {
  const LessonPlayScreen({super.key});

  @override
  State<LessonPlayScreen> createState() => _LessonPlayScreenState();
}

enum LessonPhase { loading, opening, introduce, quiz }

class _LessonPlayScreenState extends State<LessonPlayScreen> {
  LessonPhase _phase = LessonPhase.loading;
  String? _error;

  // Data
  LessonBatch? _batch;
  List<Word> _words = [];
  OpeningFrame? _openingFrame;

  // Introduce state
  int _currentWordIndex = 0;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBatch());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadBatch() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final gradeLevel = args['gradeLevel'] as int;
    final difficulty = args['difficulty'] as String;
    final student = context.read<StudentProvider>().currentStudent;

    if (student == null || student.id == null) {
      setState(() {
        _phase = LessonPhase.loading;
        _error = 'Not signed in.';
      });
      return;
    }

    try {
      final batch = await DatabaseService.instance
          .getFirstBatch(gradeLevel, difficulty);
      if (batch == null || batch.id == null) {
        setState(() {
          _phase = LessonPhase.loading;
          _error = 'No content found for this level.';
        });
        return;
      }

      final words =
          await DatabaseService.instance.getWordsInBatch(batch.id!);
      if (words.isEmpty) {
        setState(() {
          _phase = LessonPhase.loading;
          _error = 'This lesson has no words yet.';
        });
        return;
      }

      final visited = await DatabaseService.instance
          .hasVisitedBatch(student.id!, batch.id!);
      OpeningFrame? frame;
      if (!visited) {
        frame = await DatabaseService.instance
            .getOpeningFrame(gradeLevel, difficulty);
      }

      if (!mounted) return;

      setState(() {
        _batch = batch;
        _words = words;
        _openingFrame = frame;
        _phase = frame != null
            ? LessonPhase.opening
            : LessonPhase.introduce;
      });

      if (frame != null) {
        _playOpeningAudio(frame.audioAsset);
        await DatabaseService.instance
            .recordBatchVisit(student.id!, batch.id!);
      }
    } catch (e) {
      debugPrint('📚 LessonPlay load ERROR: $e');
      setState(() {
        _phase = LessonPhase.loading;
        _error = 'Could not load lesson. Try again.';
      });
    }
  }

  Future<void> _playOpeningAudio(String assetPath) async {
    try {
      final cleanPath = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _audioPlayer.play(AssetSource(cleanPath));
    } catch (e) {
      debugPrint('🔊 Opening audio failed (continuing): $e');
    }
  }

  void _skipOpening() {
    _audioPlayer.stop();
    setState(() => _phase = LessonPhase.introduce);
  }

  void _onOpeningFinished() {
    if (_phase == LessonPhase.opening) {
      setState(() => _phase = LessonPhase.introduce);
    }
  }

  Future<void> _playWordAudio(Word word) async {
    final assetPath = word.lessonCueAudio ?? word.audioAsset;

    try {
      final cleanPath = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(cleanPath));
    } catch (e) {
      debugPrint('🔊 Word cue audio failed (continuing): $e');
    }
  }

  void _nextWord() {
    _audioPlayer.stop();
    if (_currentWordIndex < _words.length - 1) {
      setState(() => _currentWordIndex++);
    } else {
      if (_batch?.id != null) {
        Navigator.of(context).pushReplacementNamed(
          '/quiz-play',
          arguments: {'batchId': _batch!.id},
        );
      }
    }
  }

  void _previousWord() {
    _audioPlayer.stop();
    if (_currentWordIndex > 0) {
      setState(() => _currentWordIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.studentBg,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _buildError();
    switch (_phase) {
      case LessonPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case LessonPhase.opening:
        return _buildOpeningFrame();
      case LessonPhase.introduce:
        return _buildIntroduce();
      case LessonPhase.quiz:
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
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // OPENING FRAME
  // ─────────────────────────────────────────────────────────

  Widget _buildOpeningFrame() {
    final frame = _openingFrame!;
    return Stack(
      children: [
        _AutoTransition(
          duration: const Duration(seconds: 4),
          onComplete: _onOpeningFinished,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: TextButton(
                    onPressed: _skipOpening,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Image.asset(
                frame.visualAsset,
                width: 280,
                height: 280,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentTeal,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    size: 120,
                    color: AppColors.accentTeal,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  frame.displayText,
                  textAlign: TextAlign.center,
                  style: AppText.h2.copyWith(
                    fontSize: 22,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // INTRODUCE PHASE
  // ─────────────────────────────────────────────────────────

  Widget _buildIntroduce() {
    final word = _words[_currentWordIndex];
    final isLast = _currentWordIndex == _words.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
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
                child: Text('Learn', style: AppText.h2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Word ${_currentWordIndex + 1} of ${_words.length}',
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: LinearProgressIndicator(
              value: (_currentWordIndex + 1) / _words.length,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentTeal,
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Image.asset(
                    word.imageAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color:
                            AppColors.studentBg.withValues(alpha: 0.6),
                        borderRadius:
                            BorderRadius.circular(AppRadius.large),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 60,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  word.text,
                  style: AppText.display.copyWith(
                    fontSize: 48,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (word.category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AppColors.accentTeal.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      word.category.replaceAll('_', ' '),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTeal,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _playWordAudio(word),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text(
                      'LISTEN',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed:
                        _currentWordIndex > 0 ? _previousWord : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentOrange,
                      side: const BorderSide(
                        color: AppColors.accentOrange,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _nextWord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLast
                          ? AppColors.accentYellow
                          : AppColors.accentTeal,
                      foregroundColor: isLast
                          ? AppColors.textPrimary
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: Text(
                      isLast ? 'Take Quiz' : 'Next',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Top-level helper widget (MUST be outside the state class)
// ─────────────────────────────────────────────────────────

class _AutoTransition extends StatefulWidget {
  final Duration duration;
  final VoidCallback onComplete;

  const _AutoTransition({
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_AutoTransition> createState() => _AutoTransitionState();
}

class _AutoTransitionState extends State<_AutoTransition> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}