/// Word content model — bundled with app, seeded from JSON.
class Word {
  final int? id;
  final String text;
  final int gradeLevel;
  final String difficulty;
  final int? batchId;
  final String category;
  final String imageAsset;
  final String audioAsset;
  final String? lessonCueAudio;
  final String lessonCue;
  final String definition;
  final String sampleSentence;
  final String source;
  final bool sensitivityReviewed;
  final String? sensitivityNotes;

  // Legacy fields — kept until M5.2 rebuilds Lesson/Quiz screens.
  // These will be removed once quiz_questions takes over.
  final List<String> quizChoices;
  final String correctAnswer;

  Word({
    this.id,
    required this.text,
    required this.gradeLevel,
    required this.difficulty,
    this.batchId,
    this.category = 'general',
    required this.imageAsset,
    required this.audioAsset,
    this.lessonCueAudio,
    this.lessonCue = '',
    this.definition = '',
    this.sampleSentence = '',
    this.source = '',
    this.sensitivityReviewed = false,
    this.sensitivityNotes,
    this.quizChoices = const [],
    this.correctAnswer = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'grade_level': gradeLevel,
      'difficulty': difficulty,
      'batch_id': batchId,
      'category': category,
      'image_asset': imageAsset,
      'audio_asset': audioAsset,
      'lesson_cue_audio': lessonCueAudio,
      'lesson_cue': lessonCue,
      'definition': definition,
      'sample_sentence': sampleSentence,
      'source': source,
      'sensitivity_reviewed': sensitivityReviewed ? 1 : 0,
      'sensitivity_notes': sensitivityNotes,
      'quiz_choices': quizChoices.join('|'),
      'correct_answer': correctAnswer,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    final choicesRaw = map['quiz_choices'] as String?;
    return Word(
      id: map['id'] as int?,
      text: map['text'] as String,
      gradeLevel: map['grade_level'] as int,
      difficulty: map['difficulty'] as String,
      batchId: map['batch_id'] as int?,
      category: (map['category'] as String?) ?? 'general',
      imageAsset: map['image_asset'] as String,
      audioAsset: map['audio_asset'] as String,
      lessonCueAudio: map['lesson_cue_audio'] as String?,
      lessonCue: (map['lesson_cue'] as String?) ?? '',
      definition: (map['definition'] as String?) ?? '',
      sampleSentence: (map['sample_sentence'] as String?) ?? '',
      source: (map['source'] as String?) ?? '',
      sensitivityReviewed:
          ((map['sensitivity_reviewed'] as int?) ?? 0) == 1,
      sensitivityNotes: map['sensitivity_notes'] as String?,
      quizChoices:
          (choicesRaw == null || choicesRaw.isEmpty) ? const [] : choicesRaw.split('|'),
      correctAnswer: (map['correct_answer'] as String?) ?? '',
    );
  }
}