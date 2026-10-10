import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/content_models.dart';
import '../models/word.dart';
import 'database_service.dart';

/// Imports bundled JSON content into SQLite on first launch.
/// Checks content_versions to avoid redundant imports.
class ContentImporter {
  static final ContentImporter instance = ContentImporter._internal();
  ContentImporter._internal();

  /// Import all grades that have JSON files bundled.
  Future<void> importAllGrades() async {
    await importGradeIfNeeded(1);
    await importGradeIfNeeded(2);
    // await importGradeIfNeeded(3);
    // ...
  }

  /// Import content for a single grade if not already up to date.
  Future<bool> importGradeIfNeeded(int gradeLevel) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/grade$gradeLevel.json',
      );
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = data['content_version'] as String;

      // Skip if already imported at this version.
      final existing =
          await DatabaseService.instance.getContentVersion(gradeLevel);
      if (existing != null && existing.version == version) {
        debugPrint('📚 grade $gradeLevel v$version already imported');
        return true;
      }

      debugPrint('📚 Importing grade $gradeLevel v$version...');

      // Clear any existing content for clean re-import.
      if (existing != null) {
        await DatabaseService.instance.clearContentForGrade(gradeLevel);
      }

      // ── 1. Lesson Intros (v13) ──
      // Cleared on re-import; upserted here.
      final lessonIntros =
          (data['lesson_intros'] as List<dynamic>?) ?? [];
      for (final introData in lessonIntros) {
        final intro = LessonIntro(
          grade: introData['grade'] as int,
          difficulty: introData['difficulty'] as String,
          header: introData['header'] as String,
          body: introData['body'] as String,
          buttonLabel: introData['button_label'] as String,
          poseAsset: introData['pose_asset'] as String,
          audioAsset: introData['audio_asset'] as String,
        );
        await DatabaseService.instance.upsertLessonIntro(intro);
      }
      debugPrint('📚 Lesson intros: ${lessonIntros.length}');

      // ── 2. Game Intros (v13) ──
      // Shared across grades — INSERT OR REPLACE, no clear.
      final gameIntros = (data['game_intros'] as List<dynamic>?) ?? [];
      for (final introData in gameIntros) {
        final intro = GameIntro(
          gameType: introData['game_type'] as String,
          header: introData['header'] as String,
          body: introData['body'] as String,
          buttonLabel: introData['button_label'] as String,
          poseAsset: introData['pose_asset'] as String,
          audioAsset: introData['audio_asset'] as String,
        );
        await DatabaseService.instance.upsertGameIntro(intro);
      }
      debugPrint('📚 Game intros: ${gameIntros.length}');

      // ── 3. Lessons ──
      final lessons = (data['lessons'] as List<dynamic>?) ?? [];
      for (final lessonData in lessons) {
        final difficulty = lessonData['difficulty'] as String;
        final theme = (lessonData['theme'] as String?) ?? '';

        // 3a. Quiz config
        final configData =
            lessonData['quiz_config'] as Map<String, dynamic>;
        final config = QuizConfig(
          gradeLevel: gradeLevel,
          difficulty: difficulty,
          quizSize: configData['quiz_size'] as int,
          bufferSize: (configData['buffer_size'] as int?) ?? 0,
          randomized: ((configData['randomized'] as int?) ?? 0) == 1,
          passingThreshold:
              (configData['passing_threshold'] as int?) ?? 70,
        );
        await DatabaseService.instance.insertQuizConfig(config);

        // 3b. Game config
        final gameConfig =
            lessonData['game_config'] as Map<String, dynamic>?;
        final gameType = gameConfig?['game_type'] as String?;

        // 3c. Batches
        final batches = (lessonData['batches'] as List<dynamic>?) ?? [];
        for (final batchData in batches) {
          final batchIndex = batchData['batch_index'] as int;

          final batch = LessonBatch(
            gradeLevel: gradeLevel,
            difficulty: difficulty,
            batchIndex: batchIndex,
            theme: theme,
            gameType: gameType,
          );
          final batchId = await DatabaseService.instance
              .upsertBatchByNaturalKey(batch);

          // 3d. Words for this batch
          final words = (batchData['words'] as List<dynamic>?) ?? [];
          int questionOrder = 0;

          for (final wordData in words) {
            final cueAudioField = wordData['lesson_cue_audio'] as String?;

            final word = Word(
              text: wordData['text'] as String,
              gradeLevel: gradeLevel,
              difficulty: difficulty,
              batchId: batchId,
              category: (wordData['category'] as String?) ?? 'general',
              imageAsset:
                  'assets/images/words/${wordData['image']}',
              audioAsset:
                  'assets/audio/words/${wordData['audio']}',
              lessonCueAudio: cueAudioField != null
                  ? 'assets/audio/cues/$cueAudioField'
                  : null,
              lessonCue: (wordData['lesson_cue'] as String?) ?? '',
              definition: (wordData['definition'] as String?) ?? '',
              sampleSentence:
                  (wordData['sample_sentence'] as String?) ?? '',
              source: (wordData['source'] as String?) ?? '',
              sensitivityReviewed:
                  ((wordData['sensitivity_reviewed'] as int?) ?? 0) ==
                      1,
              sensitivityNotes:
                  wordData['sensitivity_notes'] as String?,
            );
            final wordId = await DatabaseService.instance
                .upsertWordByNaturalKey(word);

            // Clear old questions for this word before re-inserting.
            await DatabaseService.instance.deleteQuizQuestionsForWord(wordId);

            // 3e. Quiz questions
            final questions =
                (wordData['quiz_questions'] as List<dynamic>?) ?? [];
            for (final qData in questions) {
              final q = QuizQuestion(
                batchId: batchId,
                wordId: wordId,
                questionStem: qData['stem'] as String,
                questionType: qData['type'] as String,
                correctAnswer: qData['correct'] as String,
                distractorsJson: jsonEncode(qData['distractors']),
                showImage: (qData['show_image'] as bool?) ?? true,
                orderIndex: questionOrder++,
              );
              await DatabaseService.instance.insertQuizQuestion(q);
            }
          }
        }
      }

      // ── 4. Save version record ──
      await DatabaseService.instance.saveContentVersion(
        ContentVersion(
          gradeLevel: gradeLevel,
          version: version,
          importedAt: DateTime.now().toIso8601String(),
        ),
      );

      debugPrint('📚 Grade $gradeLevel imported successfully');
      return true;
    } catch (e, stack) {
      debugPrint('📚 ContentImporter ERROR: $e');
      debugPrint('📚 STACK: $stack');
      return false;
    }
  }
}