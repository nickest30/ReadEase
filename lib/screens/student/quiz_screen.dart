import 'package:flutter/material.dart';
import '../../models/word.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answered = false;
  bool _initialized = false;
  late List<Word> _words;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>;
      _words = args['words'] as List<Word>;
    }
  }

  void _selectAnswer(String answer) {
    if (_answered) return;

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (answer == _words[_currentIndex].correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;

    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      Navigator.of(context).pushReplacementNamed(
        '/results',
        arguments: {
          ...args,
          'score': _score,
          'totalQuestions': _words.length,
        },
      );
    }
  }

  Color _choiceColor(String choice) {
    if (!_answered) return Colors.white;
    final correct = _words[_currentIndex].correctAnswer;
    if (choice == correct) return const Color(0xFFDCF1ED);
    if (choice == _selectedAnswer) return const Color(0xFFFDEAE7);
    return Colors.white;
  }

  Color _choiceBorderColor(String choice) {
    if (!_answered) return const Color(0xFFE9DCBE);
    final correct = _words[_currentIndex].correctAnswer;
    if (choice == correct) return const Color(0xFF2BAFA0);
    if (choice == _selectedAnswer) return const Color(0xFFFF6F61);
    return const Color(0xFFE9DCBE);
  }

  @override
  Widget build(BuildContext context) {
    final word = _words[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'Quiz',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),
              Text(
                'Question ${_currentIndex + 1} of ${_words.length}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _words.length,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE9DCBE),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2BAFA0),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE9DCBE)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF0D9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 38,
                        color: Color(0xFF6B7878),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'What is this?',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7878),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: ListView(
                  children: word.quizChoices.map((choice) {
                    final isCorrectChoice =
                        _answered && choice == word.correctAnswer;
                    final isWrongSelected = _answered &&
                        choice == _selectedAnswer &&
                        choice != word.correctAnswer;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _selectAnswer(choice),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 18,
                          ),
                          decoration: BoxDecoration(
                            color: _choiceColor(choice),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _choiceBorderColor(choice),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  choice,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF2E3A3A),
                                  ),
                                ),
                              ),
                              if (isCorrectChoice)
                                const Icon(Icons.check_circle,
                                    color: Color(0xFF2BAFA0)),
                              if (isWrongSelected)
                                const Icon(Icons.cancel,
                                    color: Color(0xFFFF6F61)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _answered ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFE8A93B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Next Question >',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}