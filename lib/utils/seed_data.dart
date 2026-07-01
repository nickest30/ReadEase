import '../models/word.dart';
import '../services/database_service.dart';

Future<void> seedWordsIfEmpty() async {
  final existingCount = await DatabaseService.instance.getWordCount();
  if (existingCount > 0) return; // already seeded, don't duplicate

  final words = [
    Word(
      text: 'Apple',
      gradeLevel: 1,
      difficulty: 'easy',
      imageAsset: 'assets/images/apple.png',
      audioAsset: 'assets/audio/apple.mp3',
      quizChoices: ['Apple', 'Banana', 'Mango', 'Orange'],
      correctAnswer: 'Apple',
    ),
    Word(
      text: 'Ball',
      gradeLevel: 1,
      difficulty: 'easy',
      imageAsset: 'assets/images/ball.png',
      audioAsset: 'assets/audio/ball.mp3',
      quizChoices: ['Ball', 'Box', 'Bird', 'Bag'],
      correctAnswer: 'Ball',
    ),
    Word(
      text: 'Cat',
      gradeLevel: 1,
      difficulty: 'easy',
      imageAsset: 'assets/images/cat.png',
      audioAsset: 'assets/audio/cat.mp3',
      quizChoices: ['Cat', 'Cow', 'Car', 'Cup'],
      correctAnswer: 'Cat',
    ),
    Word(
      text: 'Dog',
      gradeLevel: 1,
      difficulty: 'easy',
      imageAsset: 'assets/images/dog.png',
      audioAsset: 'assets/audio/dog.mp3',
      quizChoices: ['Dog', 'Duck', 'Door', 'Doll'],
      correctAnswer: 'Dog',
    ),
    Word(
      text: 'Egg',
      gradeLevel: 1,
      difficulty: 'easy',
      imageAsset: 'assets/images/egg.png',
      audioAsset: 'assets/audio/egg.mp3',
      quizChoices: ['Egg', 'Eye', 'Ear', 'Elephant'],
      correctAnswer: 'Egg',
    ),
  ];

  for (final word in words) {
    await DatabaseService.instance.insertWord(word);
  }
}