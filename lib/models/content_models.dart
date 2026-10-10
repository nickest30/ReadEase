// Content-side models — bundled with app, seeded from JSON.
// These represent the DATABANK, not user progress.

/// A small batch of 3-5 words within a level.
class LessonBatch {
  final int? id;
  final int gradeLevel;
  final String difficulty;
  final int batchIndex;
  final String theme;
  final String? culturalElementsJson;
  final String? gameType;          // NEW — 'memory_match' | 'bubble_pop' | 'drag_drop' | null

  LessonBatch({
    this.id,
    required this.gradeLevel,
    required this.difficulty,
    required this.batchIndex,
    required this.theme,
    this.culturalElementsJson,
    this.gameType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'grade_level': gradeLevel,
        'difficulty': difficulty,
        'batch_index': batchIndex,
        'theme': theme,
        'cultural_elements_json': culturalElementsJson,
        'game_type': gameType,
      };

  factory LessonBatch.fromMap(Map<String, dynamic> m) => LessonBatch(
        id: m['id'] as int?,
        gradeLevel: m['grade_level'] as int,
        difficulty: m['difficulty'] as String,
        batchIndex: m['batch_index'] as int,
        theme: m['theme'] as String,
        culturalElementsJson: m['cultural_elements_json'] as String?,
        gameType: m['game_type'] as String?,
      );

  String get lessonKey => 'grade${gradeLevel}_$difficulty';
}

/// Grade 1 opening frame (Yse speaks before lesson).
class OpeningFrame {
  final int? id;
  final int gradeLevel;
  final String difficulty;
  final String visualAsset;
  final String audioAsset;
  final String displayText;
  final String triggerType;

  OpeningFrame({
    this.id,
    required this.gradeLevel,
    required this.difficulty,
    required this.visualAsset,
    required this.audioAsset,
    required this.displayText,
    this.triggerType = 'first_visit_only',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'grade_level': gradeLevel,
        'difficulty': difficulty,
        'visual_asset': visualAsset,
        'audio_asset': audioAsset,
        'display_text': displayText,
        'trigger_type': triggerType,
      };

  factory OpeningFrame.fromMap(Map<String, dynamic> m) => OpeningFrame(
        id: m['id'] as int?,
        gradeLevel: m['grade_level'] as int,
        difficulty: m['difficulty'] as String,
        visualAsset: m['visual_asset'] as String,
        audioAsset: m['audio_asset'] as String,
        displayText: m['display_text'] as String,
        triggerType: m['trigger_type'] as String,
      );
}

/// Grade 2+ story frame — 2-3 screens before lesson.
class StoryFrame {
  final int? id;
  final int gradeLevel;
  final String difficulty;
  final int frameIndex;
  final String visualAsset;
  final String audioAsset;
  final String displayText;
  final int? wordIntroducedId;

  StoryFrame({
    this.id,
    required this.gradeLevel,
    required this.difficulty,
    required this.frameIndex,
    required this.visualAsset,
    required this.audioAsset,
    required this.displayText,
    this.wordIntroducedId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'grade_level': gradeLevel,
        'difficulty': difficulty,
        'frame_index': frameIndex,
        'visual_asset': visualAsset,
        'audio_asset': audioAsset,
        'display_text': displayText,
        'word_introduced_id': wordIntroducedId,
      };

  factory StoryFrame.fromMap(Map<String, dynamic> m) => StoryFrame(
        id: m['id'] as int?,
        gradeLevel: m['grade_level'] as int,
        difficulty: m['difficulty'] as String,
        frameIndex: m['frame_index'] as int,
        visualAsset: m['visual_asset'] as String,
        audioAsset: m['audio_asset'] as String,
        displayText: m['display_text'] as String,
        wordIntroducedId: m['word_introduced_id'] as int?,
      );
}

/// A single quiz question tied to a batch and word.
class QuizQuestion {
  final int? id;
  final int batchId;
  final int wordId;
  final String questionStem;
  final String questionType; // literal | inferential | critical
  final String correctAnswer;
  final String distractorsJson;
  final bool showImage;
  final int orderIndex;

  QuizQuestion({
    this.id,
    required this.batchId,
    required this.wordId,
    required this.questionStem,
    required this.questionType,
    required this.correctAnswer,
    required this.distractorsJson,
    this.showImage = true,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'batch_id': batchId,
        'word_id': wordId,
        'question_stem': questionStem,
        'question_type': questionType,
        'correct_answer': correctAnswer,
        'distractors_json': distractorsJson,
        'show_image': showImage ? 1 : 0,
        'order_index': orderIndex,
      };

  factory QuizQuestion.fromMap(Map<String, dynamic> m) => QuizQuestion(
        id: m['id'] as int?,
        batchId: m['batch_id'] as int,
        wordId: m['word_id'] as int,
        questionStem: m['question_stem'] as String,
        questionType: m['question_type'] as String,
        correctAnswer: m['correct_answer'] as String,
        distractorsJson: m['distractors_json'] as String,
        showImage: ((m['show_image'] as int?) ?? 1) == 1,
        orderIndex: m['order_index'] as int,
      );
}

/// Quiz configuration per level.
class QuizConfig {
  final int? id;
  final int gradeLevel;
  final String difficulty;
  final int quizSize;
  final int bufferSize;
  final bool randomized;
  final int passingThreshold;

  QuizConfig({
    this.id,
    required this.gradeLevel,
    required this.difficulty,
    required this.quizSize,
    this.bufferSize = 0,
    this.randomized = false,
    this.passingThreshold = 70,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'grade_level': gradeLevel,
        'difficulty': difficulty,
        'quiz_size': quizSize,
        'buffer_size': bufferSize,
        'randomized': randomized ? 1 : 0,
        'passing_threshold': passingThreshold,
      };

  factory QuizConfig.fromMap(Map<String, dynamic> m) => QuizConfig(
        id: m['id'] as int?,
        gradeLevel: m['grade_level'] as int,
        difficulty: m['difficulty'] as String,
        quizSize: m['quiz_size'] as int,
        bufferSize: m['buffer_size'] as int,
        randomized: (m['randomized'] as int) == 1,
        passingThreshold: m['passing_threshold'] as int,
      );
}

/// A reading passage (G3+).
class Passage {
  final int? id;
  final int batchId;
  final String title;
  final String fullText;
  final int wordCount;
  final int philIriTargetGrade;
  final double? philIriReadabilityScore;
  final String? philIriReadabilityTool;
  final String? culturalElementsJson;

  Passage({
    this.id,
    required this.batchId,
    required this.title,
    required this.fullText,
    required this.wordCount,
    required this.philIriTargetGrade,
    this.philIriReadabilityScore,
    this.philIriReadabilityTool,
    this.culturalElementsJson,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'batch_id': batchId,
        'title': title,
        'full_text': fullText,
        'word_count': wordCount,
        'phil_iri_target_grade': philIriTargetGrade,
        'phil_iri_readability_score': philIriReadabilityScore,
        'phil_iri_readability_tool': philIriReadabilityTool,
        'cultural_elements_json': culturalElementsJson,
      };

  factory Passage.fromMap(Map<String, dynamic> m) => Passage(
        id: m['id'] as int?,
        batchId: m['batch_id'] as int,
        title: m['title'] as String,
        fullText: m['full_text'] as String,
        wordCount: m['word_count'] as int,
        philIriTargetGrade: m['phil_iri_target_grade'] as int,
        philIriReadabilityScore:
            (m['phil_iri_readability_score'] as num?)?.toDouble(),
        philIriReadabilityTool: m['phil_iri_readability_tool'] as String?,
        culturalElementsJson: m['cultural_elements_json'] as String?,
      );
}

/// One sentence inside a passage (for audio sync).
class PassageSentence {
  final int? id;
  final int passageId;
  final int sentenceIndex;
  final String text;
  final String audioFile;

  PassageSentence({
    this.id,
    required this.passageId,
    required this.sentenceIndex,
    required this.text,
    required this.audioFile,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'passage_id': passageId,
        'sentence_index': sentenceIndex,
        'text': text,
        'audio_file': audioFile,
      };

  factory PassageSentence.fromMap(Map<String, dynamic> m) => PassageSentence(
        id: m['id'] as int?,
        passageId: m['passage_id'] as int,
        sentenceIndex: m['sentence_index'] as int,
        text: m['text'] as String,
        audioFile: m['audio_file'] as String,
      );
}

/// A word marked as encountered by a student (Pokédex "seen").
class WordEncounter {
  final int? id;
  final int studentId;
  final int wordId;
  final String firstSeenAt;
  final int timesSeen;

  WordEncounter({
    this.id,
    required this.studentId,
    required this.wordId,
    required this.firstSeenAt,
    this.timesSeen = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'word_id': wordId,
        'first_seen_at': firstSeenAt,
        'times_seen': timesSeen,
      };

  factory WordEncounter.fromMap(Map<String, dynamic> m) => WordEncounter(
        id: m['id'] as int?,
        studentId: m['student_id'] as int,
        wordId: m['word_id'] as int,
        firstSeenAt: m['first_seen_at'] as String,
        timesSeen: m['times_seen'] as int,
      );
}

/// Word mastery tracking (Pokédex "mastered").
class WordMastery {
  final int? id;
  final int studentId;
  final int wordId;
  final int correctCount;
  final int wrongCount;
  final String? masteredAt;

  WordMastery({
    this.id,
    required this.studentId,
    required this.wordId,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.masteredAt,
  });

  bool get isMastered => correctCount >= 3;

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'word_id': wordId,
        'correct_count': correctCount,
        'wrong_count': wrongCount,
        'mastered_at': masteredAt,
      };

  factory WordMastery.fromMap(Map<String, dynamic> m) => WordMastery(
        id: m['id'] as int?,
        studentId: m['student_id'] as int,
        wordId: m['word_id'] as int,
        correctCount: m['correct_count'] as int,
        wrongCount: m['wrong_count'] as int,
        masteredAt: m['mastered_at'] as String?,
      );
}

/// A word the student starred in My Dictionary.
class StarredWord {
  final int? id;
  final int studentId;
  final int wordId;
  final String starredAt;

  StarredWord({
    this.id,
    required this.studentId,
    required this.wordId,
    required this.starredAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'word_id': wordId,
        'starred_at': starredAt,
      };

  factory StarredWord.fromMap(Map<String, dynamic> m) => StarredWord(
        id: m['id'] as int?,
        studentId: m['student_id'] as int,
        wordId: m['word_id'] as int,
        starredAt: m['starred_at'] as String,
      );
}

/// Tracks first visit to a batch (Yse Opening Frame trigger).
class BatchVisit {
  final int? id;
  final int studentId;
  final int batchId;
  final String firstVisitAt;

  BatchVisit({
    this.id,
    required this.studentId,
    required this.batchId,
    required this.firstVisitAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'batch_id': batchId,
        'first_visit_at': firstVisitAt,
      };

  factory BatchVisit.fromMap(Map<String, dynamic> m) => BatchVisit(
        id: m['id'] as int?,
        studentId: m['student_id'] as int,
        batchId: m['batch_id'] as int,
        firstVisitAt: m['first_visit_at'] as String,
      );
}

/// Lesson progress (for resume).
class LessonProgress {
  final int? id;
  final int studentId;
  final int batchId;
  final String currentPhase;
  final int currentIndex;
  final String lastUpdated;

  LessonProgress({
    this.id,
    required this.studentId,
    required this.batchId,
    required this.currentPhase,
    this.currentIndex = 0,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'batch_id': batchId,
        'current_phase': currentPhase,
        'current_index': currentIndex,
        'last_updated': lastUpdated,
      };

  factory LessonProgress.fromMap(Map<String, dynamic> m) => LessonProgress(
        id: m['id'] as int?,
        studentId: m['student_id'] as int,
        batchId: m['batch_id'] as int,
        currentPhase: m['current_phase'] as String,
        currentIndex: m['current_index'] as int,
        lastUpdated: m['last_updated'] as String,
      );
}

/// A completed quiz attempt.
class QuizAttempt {
  final int? id;
  final int studentId;
  final int batchId;
  final int score;
  final int totalQuestions;
  final int pointsEarned; // DELTA, not cumulative
  final String? wrongWordIdsJson;
  final String completedAt;
  final bool syncedToCloud;

  QuizAttempt({
    this.id,
    required this.studentId,
    required this.batchId,
    required this.score,
    required this.totalQuestions,
    required this.pointsEarned,
    this.wrongWordIdsJson,
    required this.completedAt,
    this.syncedToCloud = false,
  });

  double get accuracyRate =>
      totalQuestions == 0 ? 0 : score / totalQuestions;
  bool get isPassing => accuracyRate >= 0.70;

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'batch_id': batchId,
        'score': score,
        'total_questions': totalQuestions,
        'points_earned': pointsEarned,
        'wrong_word_ids_json': wrongWordIdsJson,
        'completed_at': completedAt,
        'synced_to_cloud': syncedToCloud ? 1 : 0,
      };

  factory QuizAttempt.fromMap(Map<String, dynamic> m) => QuizAttempt(
        id: m['id'] as int?,
        studentId: m['student_id'] as int,
        batchId: m['batch_id'] as int,
        score: m['score'] as int,
        totalQuestions: m['total_questions'] as int,
        pointsEarned: m['points_earned'] as int,
        wrongWordIdsJson: m['wrong_word_ids_json'] as String?,
        completedAt: m['completed_at'] as String,
        syncedToCloud: ((m['synced_to_cloud'] as int?) ?? 0) == 1,
      );
}

/// Per-question response (analytics).
class QuizQuestionResponse {
  final int? id;
  final int attemptId;
  final int questionId;
  final String selectedAnswer;
  final bool isCorrect;
  final int? responseTimeMs;

  QuizQuestionResponse({
    this.id,
    required this.attemptId,
    required this.questionId,
    required this.selectedAnswer,
    required this.isCorrect,
    this.responseTimeMs,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'attempt_id': attemptId,
        'question_id': questionId,
        'selected_answer': selectedAnswer,
        'is_correct': isCorrect ? 1 : 0,
        'response_time_ms': responseTimeMs,
      };

  factory QuizQuestionResponse.fromMap(Map<String, dynamic> m) =>
      QuizQuestionResponse(
        id: m['id'] as int?,
        attemptId: m['attempt_id'] as int,
        questionId: m['question_id'] as int,
        selectedAnswer: m['selected_answer'] as String,
        isCorrect: (m['is_correct'] as int) == 1,
        responseTimeMs: m['response_time_ms'] as int?,
      );
}

/// Word of the Day log.
class DailyWordEntry {
  final int? id;
  final int studentId;
  final int wordId;
  final String dateShown; // YYYY-MM-DD
  final String shownAt;

  DailyWordEntry({
    this.id,
    required this.studentId,
    required this.wordId,
    required this.dateShown,
    required this.shownAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'word_id': wordId,
        'date_shown': dateShown,
        'shown_at': shownAt,
      };

  factory DailyWordEntry.fromMap(Map<String, dynamic> m) => DailyWordEntry(
        id: m['id'] as int?,
        studentId: m['student_id'] as int,
        wordId: m['word_id'] as int,
        dateShown: m['date_shown'] as String,
        shownAt: m['shown_at'] as String,
      );
}

/// Content version tracking.
class ContentVersion {
  final int? id;
  final int gradeLevel;
  final String version;
  final String importedAt;

  ContentVersion({
    this.id,
    required this.gradeLevel,
    required this.version,
    required this.importedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'grade_level': gradeLevel,
        'version': version,
        'imported_at': importedAt,
      };

  factory ContentVersion.fromMap(Map<String, dynamic> m) => ContentVersion(
        id: m['id'] as int?,
        gradeLevel: m['grade_level'] as int,
        version: m['version'] as String,
        importedAt: m['imported_at'] as String,
      );
}

class LessonIntro {
  final int? id;
  final int grade;
  final String difficulty;
  final String header;
  final String body;
  final String buttonLabel;
  final String poseAsset;
  final String audioAsset;

  LessonIntro({
    this.id,
    required this.grade,
    required this.difficulty,
    required this.header,
    required this.body,
    required this.buttonLabel,
    required this.poseAsset,
    required this.audioAsset,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'grade': grade,
        'difficulty': difficulty,
        'header': header,
        'body': body,
        'button_label': buttonLabel,
        'pose_asset': poseAsset,
        'audio_asset': audioAsset,
      };

  factory LessonIntro.fromMap(Map<String, dynamic> m) => LessonIntro(
        id: m['id'] as int?,
        grade: m['grade'] as int,
        difficulty: m['difficulty'] as String,
        header: m['header'] as String,
        body: m['body'] as String,
        buttonLabel: m['button_label'] as String,
        poseAsset: m['pose_asset'] as String,
        audioAsset: m['audio_asset'] as String,
      );
}

/// Game Intro — shown before each game session.
class GameIntro {
  final int? id;
  final String gameType;
  final String header;
  final String body;
  final String buttonLabel;
  final String poseAsset;
  final String audioAsset;

  GameIntro({
    this.id,
    required this.gameType,
    required this.header,
    required this.body,
    required this.buttonLabel,
    required this.poseAsset,
    required this.audioAsset,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'game_type': gameType,
        'header': header,
        'body': body,
        'button_label': buttonLabel,
        'pose_asset': poseAsset,
        'audio_asset': audioAsset,
      };

  factory GameIntro.fromMap(Map<String, dynamic> m) => GameIntro(
        id: m['id'] as int?,
        gameType: m['game_type'] as String,
        header: m['header'] as String,
        body: m['body'] as String,
        buttonLabel: m['button_label'] as String,
        poseAsset: m['pose_asset'] as String,
        audioAsset: m['audio_asset'] as String,
      );
}