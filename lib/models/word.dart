class Word {
  final int? id;
  final String text;
  final int gradeLevel;
  final String difficulty; // 'easy', 'medium', 'hard'
  final String imageAsset;
  final String audioAsset;
  final List<String> quizChoices;
  final String correctAnswer;

  Word({
    this.id,
    required this.text,
    required this.gradeLevel,
    required this.difficulty,
    required this.imageAsset,
    required this.audioAsset,
    required this.quizChoices,
    required this.correctAnswer,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'grade_level': gradeLevel,
      'difficulty': difficulty,
      'image_asset': imageAsset,
      'audio_asset': audioAsset,
      'quiz_choices': quizChoices.join('|'), // stored as pipe-separated text
      'correct_answer': correctAnswer,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      text: map['text'] as String,
      gradeLevel: map['grade_level'] as int,
      difficulty: map['difficulty'] as String,
      imageAsset: map['image_asset'] as String,
      audioAsset: map['audio_asset'] as String,
      quizChoices: (map['quiz_choices'] as String).split('|'),
      correctAnswer: map['correct_answer'] as String,
    );
  }
}