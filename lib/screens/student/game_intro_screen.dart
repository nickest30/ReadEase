import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/content_models.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';

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
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/student-home',
            (route) => false,
          );
        }
      });
      return;
    }

    final gameType = args['gameType'] as String?;

    final student = context.read<StudentProvider>().currentStudent;
    if (student == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    if (gameType == null) {
      _navigateToGame(gameType, args);
      return;
    }

    final intro = await DatabaseService.instance.getGameIntro(gameType);
    if (!mounted) return;

    if (intro == null) {
      _navigateToGame(gameType, args);
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
      debugPrint('Game intro audio missing: $e');
    }
  }

  void _navigateToGame(String? gameType, Map args) {
    final route = switch (gameType) {
      'memory_match' => '/memory-match',
      'bubble_pop' => '/bubble-pop',
      'drag_drop' => '/drag-drop',
      'word_scramble' => '/word-scramble',
      'sentence_builder' => '/sentence-builder',
      'floor_is_lava' => '/floor-is-lava',
      'word_hunt' => '/word-hunt',
      'category_sort' => '/category-sort',
      _ => '/quiz-play',
    };

    Navigator.of(context).pushReplacementNamed(
      route,
      arguments: {
        'batchId': args['batchId'],
        'gradeLevel': args['gradeLevel'],
        'difficulty': args['difficulty'],
        'passageCorrect': args['passageCorrect'] ?? 0,
        'passageTotal': args['passageTotal'] ?? 0,
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
            child: Text(
              _error ?? 'Could not load intro.',
              style: AppText.body,
            ),
          ),
        ),
      );
    }

    final intro = _intro!;
    final isTablet = Responsive.isTablet(context);
    final imgSize = Responsive.imageSize(context, base: 220);
    final buttonHeight = Responsive.buttonHeight(context) + 8;

    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 20,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/mascot/${intro.poseAsset}',
            width: imgSize,
            height: imgSize,
            cacheWidth: (imgSize * 2).toInt(),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => SizedBox(
              width: imgSize,
              height: imgSize,
              child: Icon(
                Icons.auto_stories_rounded,
                size: imgSize * 0.6,
                color: AppColors.accentTeal,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            intro.header,
            textAlign: TextAlign.center,
            style: AppText.h1.copyWith(
              fontSize: 30,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            intro.body,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(
              fontSize: 18,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            height: buttonHeight,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                SfxService.tap();
                _audioPlayer.stop();
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is! Map) return;
                _navigateToGame(args['gameType'] as String?, args);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                elevation: 3,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  intro.buttonLabel,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: content),
    );
  }
}