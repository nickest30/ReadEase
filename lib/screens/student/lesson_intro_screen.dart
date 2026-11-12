import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/content_models.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';

class LessonIntroScreen extends StatefulWidget {
  const LessonIntroScreen({super.key});

  @override
  State<LessonIntroScreen> createState() => _LessonIntroScreenState();
}

class _LessonIntroScreenState extends State<LessonIntroScreen> {
  bool _loading = true;
  String? _error;
  LessonIntro? _intro;

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

    final gradeLevel = args['gradeLevel'] as int;
    final difficulty = args['difficulty'] as String;

    final student = context.read<StudentProvider>().currentStudent;
    if (student == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    final intro = await DatabaseService.instance
        .getLessonIntro(gradeLevel, difficulty);

    if (!mounted) return;

    if (intro == null) {
      Navigator.of(context).pushReplacementNamed(
        '/lesson-play',
        arguments: {
          'gradeLevel': gradeLevel,
          'difficulty': difficulty,
        },
      );
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
      debugPrint('Lesson intro audio missing: $e');
    }
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
    final imgSize = Responsive.imageSize(context, base: 260);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final buttonHeight = Responsive.buttonHeight(context) + 8;

    Widget content = Stack(
      children: [
        Positioned(
          left: -20,
          bottom: -20,
          child: Image.asset(
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
        ),
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: imgSize * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    intro.header,
                    textAlign: TextAlign.center,
                    style: AppText.h1.copyWith(
                      fontSize: 30,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
                    child: ElevatedButton(
                      onPressed: () {
                        SfxService.tap();
                        _audioPlayer.stop();
                        final args = ModalRoute.of(context)?.settings.arguments;
                        if (args is! Map) return;
                        Navigator.of(context).pushReplacementNamed(
                          '/lesson-play',
                          arguments: {
                            'gradeLevel': args['gradeLevel'],
                            'difficulty': args['difficulty'],
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
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
            ),
          ),
        ),
      ],
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