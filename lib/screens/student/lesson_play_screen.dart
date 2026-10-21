import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/content_models.dart';
import '../../models/word.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../../services/bgm_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/info_button.dart';
import 'pronunciation_modal.dart';

class LessonPlayScreen extends StatefulWidget {
  const LessonPlayScreen({super.key});

  @override
  State<LessonPlayScreen> createState() => _LessonPlayScreenState();
}

class _LessonPlayScreenState extends State<LessonPlayScreen> {
  bool _loading = true;
  String? _error;

  LessonBatch? _batch;
  List<Word> _words = [];
  int _currentWordIndex = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    BgmService.playTrack(BgmTrack.lesson);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBatch());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadBatch() async {
    // SAFE ROUTE ARGUMENTS FALLBACK
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/student-home', (route) => false);
        }
      });
      return;
    }

    final gradeLevel = args['gradeLevel'] as int?;
    final difficulty = args['difficulty'] as String?;
    
    if (gradeLevel == null || difficulty == null) {
      setState(() {
        _loading = false;
        _error = 'Missing lesson parameters.';
      });
      return;
    }

    final student = context.read<StudentProvider>().currentStudent;

    if (student == null || student.id == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    try {
      final batch = await DatabaseService.instance
          .getFirstBatch(gradeLevel, difficulty);
      if (batch == null || batch.id == null) {
        setState(() {
          _loading = false;
          _error = 'No content found for this level.';
        });
        return;
      }

      final words =
          await DatabaseService.instance.getWordsInBatch(batch.id!);
      if (words.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'This lesson has no words yet.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _batch = batch;
        _words = words;
        _loading = false;
      });

      // Record encounter for each word as the lesson loads.
      final studentId = student.id!;
      for (final w in words) {
        if (w.id != null) {
          try {
            await DatabaseService.instance
                .recordWordEncounter(studentId, w.id!);
          } catch (e) {
            debugPrint('Encounter record failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('LessonPlay load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load lesson. Try again.';
      });
    }
  }

  Future<void> _playWordAudio(Word word) async {
    SfxService.tap();
    final assetPath = word.lessonCueAudio ?? word.audioAsset;

    try {
      final cleanPath = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(cleanPath));
    } catch (e) {
      debugPrint('Word cue audio failed (continuing): $e');
    }
  }

  Future<void> _openPractice(Word word) async {
    SfxService.tap();
    final student = context.read<StudentProvider>().currentStudent;
    if (student?.id == null) return;

    final isOnline = context.read<ConnectivityProvider>().isOnline;

    // Stop any playing cue audio before opening the modal.
    try {
      await _audioPlayer.stop();
    } catch (_) {}

    if (!mounted) return;

    await PronunciationModal.show(
      context,
      word: word,
      studentId: student!.id!,
      isOnline: isOnline,
      updateMastery: false,
    );
  }

  void _nextWord() {
    SfxService.tap();
    _audioPlayer.stop();
    if (_currentWordIndex < _words.length - 1) {
      setState(() => _currentWordIndex++);
    } else {
      if (_batch?.id == null) return;

      final args = {
        'batchId': _batch!.id,
        'gradeLevel': _batch!.gradeLevel,
        'difficulty': _batch!.difficulty,
        'gameType': _batch!.gameType,
      };

      final route = _batch!.passageId != null ? '/passage' : '/game-intro';

      if (_batch!.passageId != null) {
        args['passageId'] = _batch!.passageId!;
      }

      Navigator.of(context).pushReplacementNamed(route, arguments: args);
    }
  }

  void _previousWord() {
    SfxService.tap();
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError();
    }
    return _buildIntroduce();
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

  Widget _buildIntroduce() {
    final word = _words[_currentWordIndex];
    final isLast = _currentWordIndex == _words.length - 1;

    final screenH = MediaQuery.of(context).size.height;
    final imageSize = (screenH * 0.35).clamp(240.0, 320.0);

    // RESPONSIVENESS FIX: Constrain width for tablets
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
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
                  const Expanded(
                    child: Text('Learn', style: AppText.h2),
                  ),
                  const InfoButton(
                    title: 'How to Learn',
                    description: 'Look at the picture and listen to the word.',
                    steps: [
                      'Tap LISTEN to hear the word.',
                      'Tap PRACTICE to try saying it.',
                      'Tap Next to go to the next word.',
                      'When you finish all words, the game starts!',
                    ],
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
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: imageSize,
                      height: imageSize,
                      child: Image.asset(
                        word.imageAsset,
                        fit: BoxFit.contain,
                        cacheWidth: 400, // MEMORY CACHING FIX
                        errorBuilder: (_, _, _) => Container(
                          width: imageSize,
                          height: imageSize,
                          decoration: BoxDecoration(
                            color: AppColors.studentBg.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.large),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            size: 60,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    SizedBox(
                      width: double.infinity,
                      height: 90,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          word.text,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 64,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (word.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.small),
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
                    const SizedBox(height: AppSpacing.md),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () => _playWordAudio(word),
                              icon: const Icon(Icons.volume_up_rounded,
                                  size: 20),
                              label: const Text(
                                'LISTEN',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
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
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () => _openPractice(word),
                              icon: const Icon(Icons.mic_rounded, size: 20),
                              label: const Text(
                                'PRACTICE',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentTeal,
                                side: const BorderSide(
                                  color: AppColors.accentTeal,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.large),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                          isLast
                              ? (_batch?.passageId != null
                                  ? 'Read the Passage'
                                  : 'Start Game')
                              : 'Next',
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
        ),
      ),
    );
  }
}