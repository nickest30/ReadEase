import 'package:flutter/material.dart';
import '../../models/word.dart';
import '../../services/database_service.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadWords();
    }
  }

  Future<void> _loadWords() async {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final gradeLevel = args['gradeLevel'] as int;
    final difficulty = args['difficulty'] as String;

    final words = await DatabaseService.instance
        .getWords(gradeLevel, difficulty);

    if (!mounted) return;
    setState(() {
      _words = words;
      _loading = false;
    });
  }

  void _next() {
    if (_currentIndex < _words.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _playAudio() {
    // Audio playback wired up later once the audioplayers package
    // and real MP3 assets are in place. For now this is a no-op.
  }

  void _startQuiz() {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;

    Navigator.of(context).pushReplacementNamed(
      '/quiz',
      arguments: {
        ...args,
        'words': _words,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCF0D9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCF0D9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No words available yet for this grade/difficulty.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 15),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final word = _words[_currentIndex];
    final isLastWord = _currentIndex == _words.length - 1;
    final allWordsViewed = _currentIndex == _words.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3A3A)),
                  ),
                  const Expanded(
                    child: Text(
                      'Lesson',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E3A3A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balances the back button
                ],
              ),
              Text(
                'Word ${_currentIndex + 1} of ${_words.length}',
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

              const Spacer(),

              // Word card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE9DCBE)),
                ),
                child: Column(
                  children: [
                    // Image placeholder — real images come from research team later
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF0D9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 44,
                        color: Color(0xFF6B7878),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      word.text,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E3A3A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    IconButton(
                      onPressed: _playAudio,
                      icon: const Icon(Icons.volume_up_rounded),
                      iconSize: 30,
                      color: const Color(0xFF2BAFA0),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFDCF1ED),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentIndex > 0 ? _previous : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: const Color(0xFFFF6F61),
                        side: const BorderSide(color: Color(0xFFFF6F61)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '< Previous',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLastWord ? null : _next,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2BAFA0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Next >',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: allWordsViewed ? _startQuiz : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: allWordsViewed
                        ? const Color(0xFFE8A93B)
                        : const Color(0xFFE9DCBE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Take Quiz',
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