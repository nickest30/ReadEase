import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/content_models.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

/// Game Intro — shown before each game session every time.
///
/// Layout: Yse um_actually top-middle, header below, body, and
/// "I'M READY!" button bottom-center. Plays game intro audio on load.
/// Button routes to the correct game screen based on game_type.
class GameIntroScreen extends StatefulWidget {
  const GameIntroScreen({super.key});

  @override
  State<GameIntroScreen> createState() => _GameIntroScreenState();
}

class _GameIntroScreenState extends State<GameIntroScreen> {
  bool _loading = true;
  String? _error;
  GameIntro? _intro;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final gameType = args['gameType'] as String;

    final student = context.read<StudentProvider>().currentStudent;
    if (student == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    final intro =
        await DatabaseService.instance.getGameIntro(gameType);

    if (!mounted) return;

    // Defensive: skip straight to game if no intro configured.
    if (intro == null) {
      _navigateToGame(gameType);
      return;
    }

    setState(() {
      _intro = intro;
      _loading = false;
    });

    _playAudio(intro.audioAsset);
  }

  Future<void> _playAudio(String filename) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/intros/$filename'));
    } catch (e) {
      debugPrint('🔊 Game intro audio missing: $e');
    }
  }

  void _onReady() {
    _audioPlayer.stop();
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    _navigateToGame(args['gameType'] as String, args: args);
  }

  void _navigateToGame(String gameType, {Map? args}) {
    final route = switch (gameType) {
      'memory_match' => '/memory-match',
      'bubble_pop' => '/bubble-pop',
      'drag_drop' => '/drag-drop',
      'word_scramble' => '/word-scramble', // built in next batch
      _ => '/quiz-play', // fallback to MCQ for unbuilt games
    };

    final navArgs = args ??
        ModalRoute.of(context)!.settings.arguments as Map;

    Navigator.of(context).pushReplacementNamed(
      route,
      arguments: {
        'batchId': navArgs['batchId'],
        'gradeLevel': navArgs['gradeLevel'],
        'difficulty': navArgs['difficulty'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _intro == null) {
      return Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(_error ?? 'Could not load intro.',
                style: AppText.body),
          ),
        ),
      );
    }

    final intro = _intro!;

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Yse pose (top-middle)
              Image.asset(
                'assets/images/mascot/${intro.poseAsset}',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 200,
                  height: 200,
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 120,
                    color: AppColors.accentTeal,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Header
              Text(
                intro.header,
                textAlign: TextAlign.center,
                style: AppText.h1.copyWith(
                  fontSize: 28,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Body
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Text(
                  intro.body,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    fontSize: 17,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const Spacer(),

              // Button
              SizedBox(
                height: 64,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onReady,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.large),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    intro.buttonLabel,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}