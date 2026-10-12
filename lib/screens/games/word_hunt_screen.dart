import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/badge.dart';
import '../../models/content_models.dart';
import '../../models/word.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/game_sfx.dart';
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/game_score.dart';

/// Word Hunt — Grade 5 Hard.
class WordHuntScreen extends StatefulWidget {
  const WordHuntScreen({super.key});

  @override
  State<WordHuntScreen> createState() => _WordHuntScreenState();
}

class _WordHuntScreenState extends State<WordHuntScreen> {
  static const int _gridSize = 10;
  static const int _wordsPerRound = 6;
  static const int _hintAfterSeconds = 60;
  static const int _autoRevealAfterSeconds = 120;
  static const int _revealCountdownSeconds = 30;

  static const double _logicalGridSide = 400.0;
  static const double _logicalCellSize = _logicalGridSide / _gridSize;

  static const List<Color> _palette = [
    Color(0xFF4A9EFF), // blue
    Color(0xFF4CAF50), // green
    Color(0xFFFF9800), // orange
    Color(0xFF9C27B0), // purple
    Color(0xFFE91E63), // pink
    Color(0xFF009688), // teal
  ];

  /// Bright orange for revealed-but-not-found words on time-up.
  static const Color _missedColor = Color(0xFFFF5722);

  bool _loading = true;
  String? _error;

  int _batchId = 0;
  int _studentId = 0;
  int _gradeLevel = 5;
  String _difficulty = 'hard';

  List<List<String>> _cells = [];
  List<_PlacedWord> _placedWords = [];

  final Set<String> _foundWords = {};
  final Map<int, Color> _foundCellColors = {};
  final Map<int, BorderRadius> _foundCellRadii = {};
  final Map<String, Color> _wordColors = {};
  int _foundCount = 0;

  int? _dragStartIndex;
  List<int> _previewPath = [];
  bool _previewValid = false;

  Timer? _ticker;
  int _elapsedSeconds = 0;
  bool _hintFired = false;
  bool _autoRevealFired = false;
  bool _gameOver = false;
  int _revealCountdown = _revealCountdownSeconds;
  final Set<int> _hintCells = {};

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<int> _wrongWordIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGame());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // Load
  // ────────────────────────────────────────────────────────────

  Future<void> _loadGame() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final batchId = args['batchId'] as int;
    final gradeLevel = (args['gradeLevel'] as int?) ?? 5;
    final difficulty = (args['difficulty'] as String?) ?? 'hard';
    final student = context.read<StudentProvider>().currentStudent;

    if (student == null || student.id == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    try {
      final words =
          await DatabaseService.instance.getSampledWordsForBatch(batchId);

      if (words.length < _wordsPerRound) {
        setState(() {
          _loading = false;
          _error = 'Not enough words for Word Hunt.';
        });
        return;
      }

      final grid = _generateGridWithRetry(words);
      if (grid == null) {
        setState(() {
          _loading = false;
          _error = 'Could not build grid. Try again.';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _cells = grid.cells;
        _placedWords = grid.placedWords;
        _batchId = batchId;
        _studentId = student.id!;
        _gradeLevel = gradeLevel;
        _difficulty = difficulty;
        _loading = false;
      });

      _startTicker();
    } catch (e) {
      debugPrint('🔍 WordHunt load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load game. Try again.';
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (_gameOver) {
        if (_revealCountdown > 0) {
          setState(() => _revealCountdown--);
        } else {
          _ticker?.cancel();
          _finishGame();
        }
        return;
      }

      setState(() => _elapsedSeconds++);

      if (!_hintFired && _elapsedSeconds >= _hintAfterSeconds) {
        _fireHint();
      }
      if (!_autoRevealFired && _elapsedSeconds >= _autoRevealAfterSeconds) {
        _fireAutoReveal();
      }
    });
  }

  // ────────────────────────────────────────────────────────────
  // Grid generation
  // ────────────────────────────────────────────────────────────

  _GridResult? _generateGridWithRetry(List<Word> allWords) {
    final rng = Random();
    for (int attempt = 0; attempt < 30; attempt++) {
      final shuffled = List<Word>.from(allWords)..shuffle(rng);
      final picked = shuffled.take(_wordsPerRound).toList();
      final result = _generateGrid(picked, rng);
      if (result.placedWords.length == _wordsPerRound) return result;
    }
    return null;
  }

  _GridResult _generateGrid(List<Word> words, Random rng) {
    final cells = List.generate(_gridSize, (_) => List.filled(_gridSize, ''));
    final placements = <_PlacedWord>[];

    final sorted = List<Word>.from(words)
      ..sort((a, b) => b.text.length.compareTo(a.text.length));

    for (final w in sorted) {
      final upper = w.text.toUpperCase().trim();
      if (upper.isEmpty || upper.length > _gridSize) continue;
      if (!RegExp(r'^[A-Z]+$').hasMatch(upper)) continue;

      bool placed = false;
      final dirs = const [
        [0, 1], [0, -1], [1, 0], [-1, 0],
        [1, 1], [1, -1], [-1, 1], [-1, -1],
      ];
      final shuffledDirs = List<List<int>>.from(dirs)..shuffle(rng);

      for (final dir in shuffledDirs) {
        if (placed) break;
        final dr = dir[0];
        final dc = dir[1];

        int rowMin = 0, rowMax = _gridSize - 1;
        int colMin = 0, colMax = _gridSize - 1;
        if (dr > 0) rowMax = _gridSize - upper.length;
        if (dr < 0) rowMin = upper.length - 1;
        if (dc > 0) colMax = _gridSize - upper.length;
        if (dc < 0) colMin = upper.length - 1;
        if (rowMin > rowMax || colMin > colMax) continue;

        final starts = <List<int>>[];
        for (int r = rowMin; r <= rowMax; r++) {
          for (int c = colMin; c <= colMax; c++) {
            starts.add([r, c]);
          }
        }
        starts.shuffle(rng);

        for (final s in starts) {
          if (placed) break;
          final sr = s[0], sc = s[1];

          bool fits = true;
          for (int i = 0; i < upper.length; i++) {
            final r = sr + dr * i;
            final c = sc + dc * i;
            if (cells[r][c].isNotEmpty && cells[r][c] != upper[i]) {
              fits = false;
              break;
            }
          }
          if (!fits) continue;

          for (int i = 0; i < upper.length; i++) {
            cells[sr + dr * i][sc + dc * i] = upper[i];
          }
          placements.add(_PlacedWord(
            word: upper,
            wordId: w.id!,
            audioAsset: w.audioAsset,
            startRow: sr,
            startCol: sc,
            dRow: dr,
            dCol: dc,
          ));
          placed = true;
        }
      }
    }

    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (cells[r][c].isEmpty) {
          cells[r][c] = String.fromCharCode(65 + rng.nextInt(26));
        }
      }
    }

    return _GridResult(cells: cells, placedWords: placements);
  }

  // ────────────────────────────────────────────────────────────
  // Rounded-end helper for path highlighting
  // ────────────────────────────────────────────────────────────

  /// Returns the BorderRadius for a cell at position `i` within `path`.
  /// Only the head and tail cells get rounded (on the outward-facing side).
  /// Middle cells stay square so they tile seamlessly with neighbors.
  BorderRadius _radiusForPathPosition(List<int> path, int i) {
    const r = 14.0;
    if (path.length == 1) return BorderRadius.circular(r);

    final isHead = i == 0;
    final isTail = i == path.length - 1;
    if (!isHead && !isTail) return BorderRadius.zero;

    final idx = path[i];
    final neighborIdx = isHead ? path[1] : path[path.length - 2];

    final row = idx ~/ _gridSize;
    final col = idx % _gridSize;
    final nRow = neighborIdx ~/ _gridSize;
    final nCol = neighborIdx % _gridSize;

    final dr = row - nRow; // outward direction
    final dc = col - nCol;

    return BorderRadius.only(
      topLeft: (dr <= 0 && dc <= 0) ? Radius.circular(r) : Radius.zero,
      topRight: (dr <= 0 && dc >= 0) ? Radius.circular(r) : Radius.zero,
      bottomLeft: (dr >= 0 && dc <= 0) ? Radius.circular(r) : Radius.zero,
      bottomRight: (dr >= 0 && dc >= 0) ? Radius.circular(r) : Radius.zero,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Drag
  // ────────────────────────────────────────────────────────────

  int? _cellIndexFromLocal(Offset p) {
    const cs = _logicalCellSize;
    if (p.dx < -cs * 0.5) return null;
    if (p.dy < -cs * 0.5) return null;
    if (p.dx > cs * (_gridSize + 0.5)) return null;
    if (p.dy > cs * (_gridSize + 0.5)) return null;

    final col = (p.dx / cs).floor().clamp(0, _gridSize - 1);
    final row = (p.dy / cs).floor().clamp(0, _gridSize - 1);
    return row * _gridSize + col;
  }

  void _onDragStart(Offset localPos) {
    if (_gameOver) return;
    final idx = _cellIndexFromLocal(localPos);
    if (idx == null || _foundCellColors.containsKey(idx)) return;

    HapticFeedback.selectionClick();
    setState(() {
      _dragStartIndex = idx;
      _previewPath = [idx];
      _previewValid = false;
    });
  }

  void _onDragUpdate(Offset localPos) {
    if (_gameOver || _dragStartIndex == null) return;
    final idx = _cellIndexFromLocal(localPos);
    if (idx == null) return;

    final path = _computeStraightPath(_dragStartIndex!, idx);
    setState(() {
      if (path == null) {
        _previewPath = [_dragStartIndex!];
        _previewValid = false;
      } else {
        _previewPath = path;
        _previewValid = true;
      }
    });
  }

  Future<void> _onDragEnd() async {
    if (_gameOver) return;
    if (_dragStartIndex == null || !_previewValid) {
      setState(() {
        _dragStartIndex = null;
        _previewPath = [];
        _previewValid = false;
      });
      return;
    }

    final letters = _previewPath
        .map((i) => _cells[i ~/ _gridSize][i % _gridSize])
        .join();
    final reversed = letters.split('').reversed.join();

    _PlacedWord? match;
    for (final p in _placedWords) {
      if (_foundWords.contains(p.word)) continue;
      if (p.word == letters || p.word == reversed) {
        match = p;
        break;
      }
    }

    if (match == null) {
      HapticFeedback.mediumImpact();
      GameSfx.instance.playWrong();
      final capturedPath = List<int>.from(_previewPath);
      setState(() {
        _dragStartIndex = null;
        _previewValid = false;
        _previewPath = capturedPath;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        if (_dragStartIndex == null && !_previewValid) {
          _previewPath = [];
        }
      });
      return;
    }

    await _onWordFound(match);
  }

  void _cancelDrag() {
    setState(() {
      _dragStartIndex = null;
      _previewPath = [];
      _previewValid = false;
    });
  }

  List<int>? _computeStraightPath(int a, int b) {
    if (a == b) return [a];
    final r1 = a ~/ _gridSize;
    final c1 = a % _gridSize;
    final r2 = b ~/ _gridSize;
    final c2 = b % _gridSize;

    final rowDiff = (r2 - r1).abs();
    final colDiff = (c2 - c1).abs();

    if (rowDiff != 0 && colDiff != 0 && rowDiff != colDiff) return null;

    final dr = (r2 - r1).sign;
    final dc = (c2 - c1).sign;
    final length = max(rowDiff, colDiff) + 1;

    final path = <int>[];
    for (int i = 0; i < length; i++) {
      final r = r1 + dr * i;
      final c = c1 + dc * i;
      if (r < 0 || r >= _gridSize || c < 0 || c >= _gridSize) return null;
      path.add(r * _gridSize + c);
    }
    return path;
  }

  Future<void> _onWordFound(_PlacedWord match) async {
    HapticFeedback.heavyImpact();
    GameSfx.instance.playCorrect();

    final colorIdx = _foundWords.length % _palette.length;
    final color = _palette[colorIdx];

    final path = match.path(_gridSize);

    setState(() {
      _foundWords.add(match.word);
      _wordColors[match.word] = color;
      _foundCount++;
      for (int i = 0; i < path.length; i++) {
        final idx = path[i];
        _foundCellColors[idx] = color;
        _foundCellRadii[idx] = _radiusForPathPosition(path, i);
      }
      _dragStartIndex = null;
      _previewPath = [];
      _previewValid = false;
      _hintCells.removeWhere((c) => path.contains(c));
    });

    await _playAudio(match.audioAsset);
    if (!mounted) return;

    if (_foundCount >= _placedWords.length) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      await _finishGame();
    }
  }

  Future<void> _playAudio(String assetPath) async {
    if (assetPath.isEmpty) return;
    try {
      final clean = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(clean));
    } catch (e) {
      debugPrint('🔊 Word audio failed (continuing): $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Hint + auto-reveal
  // ────────────────────────────────────────────────────────────

  void _fireHint() {
    _hintFired = true;
    final unfound =
        _placedWords.where((p) => !_foundWords.contains(p.word)).toList();
    if (unfound.isEmpty) return;

    final pick = unfound[Random().nextInt(unfound.length)];
    final startIdx = pick.startRow * _gridSize + pick.startCol;

    setState(() => _hintCells.add(startIdx));
  }

  Future<void> _fireAutoReveal() async {
    _autoRevealFired = true;
    final unfound =
        _placedWords.where((p) => !_foundWords.contains(p.word)).toList();
    if (unfound.isEmpty) return;

    setState(() {
      _gameOver = true;
      _revealCountdown = _revealCountdownSeconds;
      for (final p in unfound) {
        _wrongWordIds.add(p.wordId);
        _wordColors[p.word] = _missedColor;
        final path = p.path(_gridSize);
        for (int i = 0; i < path.length; i++) {
          final idx = path[i];
          _foundCellColors[idx] = _missedColor;
          _foundCellRadii[idx] = _radiusForPathPosition(path, i);
        }
      }
    });
    GameSfx.instance.playWrong();
  }

  // ────────────────────────────────────────────────────────────
  // Finish
  // ────────────────────────────────────────────────────────────

  Future<void> _finishGame() async {
    if (_ticker?.isActive ?? false) _ticker!.cancel();
    try {
      if (!_autoRevealFired && _foundCount >= _placedWords.length) {
        GameSfx.instance.playCelebration();
        await Future.delayed(const Duration(milliseconds: 1200));
      }
      if (!mounted) return;

      final totalRounds = _placedWords.length;
      final wrongWordIds = List<int>.from(_wrongWordIds);

      final args = ModalRoute.of(context)!.settings.arguments as Map;
      final score = GameScore.fromArgs(
        args,
        gameCorrect: _foundCount,
        gameTotal: totalRounds,
      );

      final pointsDelta =
          await DatabaseService.instance.computePointsDeltaForBatch(
        studentId: _studentId,
        batchId: _batchId,
        newScore: score.correct,
      );

      await DatabaseService.instance.saveQuizAttempt(
        QuizAttempt(
          studentId: _studentId,
          batchId: _batchId,
          score: score.correct,
          totalQuestions: score.total,
          pointsEarned: pointsDelta,
          wrongWordIdsJson: wrongWordIds.isEmpty
              ? null
              : '[${wrongWordIds.join(',')}]',
          completedAt: DateTime.now().toIso8601String(),
        ),
      );

      for (final p in _placedWords) {
        final wasCorrect = !_wrongWordIds.contains(p.wordId);
        await DatabaseService.instance
            .recordWordEncounter(_studentId, p.wordId);
        await DatabaseService.instance.updateWordMastery(
          studentId: _studentId,
          wordId: p.wordId,
          correct: wasCorrect,
        );
      }

      if (pointsDelta > 0) {
        await DatabaseService.instance.addPoints(_studentId, pointsDelta);
      }

      bool isNewBadge = false;
      final isPassing =
          totalRounds > 0 && (_foundCount / totalRounds) >= 0.70;
      if (isPassing) {
        final badgeName =
            AchievementBadge.nameFor(_gradeLevel, _difficulty);
        final badge = AchievementBadge(
          studentId: _studentId,
          gradeLevel: _gradeLevel,
          difficulty: _difficulty,
          badgeName: badgeName,
          pointsEarned: pointsDelta,
          earnedAt: DateTime.now().toIso8601String(),
        );
        isNewBadge = await DatabaseService.instance.awardBadge(badge);
      }

      final updated =
          await DatabaseService.instance.getStudentById(_studentId);
      if (!mounted) return;

      if (updated != null) {
        context.read<StudentProvider>().setStudent(updated);

        final connectivity = context.read<ConnectivityProvider>();
        final authProvider = context.read<AuthProvider>();
        unawaited(
          SyncService.instance.syncAll(
            student: updated,
            connectivity: connectivity,
            authProvider: authProvider,
          ),
        );

        if (updated.classFirestoreId != null &&
            updated.classFirestoreId!.isNotEmpty &&
            updated.firebaseUid != null) {
          try {
            final badges = await DatabaseService.instance
                .getBadgesForStudent(updated.id!);
            await FirestoreService.instance.updateEnrollmentSnapshot(
              classId: updated.classFirestoreId!,
              studentUid: updated.firebaseUid!,
              totalPoints: updated.totalPoints,
              badgeCount: badges.length,
            );
          } catch (e) {
            debugPrint('🔥 Enrollment snapshot failed: $e');
          }
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '/results',
        arguments: {
          'score': score.correct,
          'totalQuestions': score.total,
          'pointsDelta': pointsDelta,
          'gradeLevel': _gradeLevel,
          'difficulty': _difficulty,
          'isNewBadge': isNewBadge,
        },
      );
    } catch (e) {
      debugPrint('🔍 WordHunt finish ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save results. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    return _buildGame();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(_error!, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Color _gridGlowColor() {
    if (_gameOver) return _missedColor;
    if (_elapsedSeconds < 45) return const Color(0xFF4CAF50); // green
    if (_elapsedSeconds < 90) return const Color(0xFFFF9800); // orange
    return const Color(0xFFE53935); // red
  }

  String _ysePose() {
    if (_foundCount >= _placedWords.length && _placedWords.isNotEmpty) {
      return 'assets/images/mascot/yse_you_did_it.png';
    }
    if (_gameOver && _foundCount < _placedWords.length) {
      return 'assets/images/mascot/yse_try_again.png';
    }
    return 'assets/images/mascot/yse_thinking.png';
  }

  Widget _buildGame() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                // Yse — pose depends on game state
                Flexible(
                  flex: 2,
                  child: Image.asset(
                    _ysePose(),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.search_rounded,
                      size: 80,
                      color: AppColors.accentTeal,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Reveal banner on time-up
                if (_gameOver)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _missedColor.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: _missedColor, width: 2),
                      ),
                      child: Text(
                        "Time's up! See where the words were. Continuing in ${_revealCountdown}s",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF5722),
                        ),
                      ),
                    ),
                  ),

                _buildWordList(),
                const SizedBox(height: 6),

                // Grid
                Flexible(
                  flex: 6,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _logicalGridSide,
                      height: _logicalGridSide,
                      child: _buildGrid(),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                _buildBigStat(
                  icon: Icons.timer_rounded,
                  color: _gridGlowColor(),
                  label: 'TIME',
                  value: _formatTime(_elapsedSeconds),
                ),

                const SizedBox(height: 6),

                _buildBigStat(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.accentTeal,
                  label: 'FOUND',
                  value: '$_foundCount / ${_placedWords.length}',
                ),

                if (_gameOver) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _ticker?.cancel();
                        _finishGame();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                      child: const Text(
                        'CONTINUE NOW',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find the Words!', style: AppText.h2),
                SizedBox(height: 2),
                Text(
                  'Drag from first letter to last letter',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: _placedWords.map((p) {
        final found = _foundWords.contains(p.word);
        final missed = _gameOver &&
            !_foundWords.contains(p.word) &&
            _autoRevealFired;
        final color = _wordColors[p.word] ?? AppColors.accentTeal;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (found || missed)
                ? color.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(
              color: (found || missed) ? color : AppColors.border,
              width: (found || missed) ? 2 : 1,
            ),
          ),
          child: Text(
            p.word,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: (found || missed) ? color : AppColors.textPrimary,
              decoration: found ? TextDecoration.lineThrough : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid() {
    final glow = _gridGlowColor();

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _onDragStart(e.localPosition),
      onPointerMove: (e) => _onDragUpdate(e.localPosition),
      onPointerUp: (e) => _onDragEnd(),
      onPointerCancel: (e) => _cancelDrag(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: glow, width: 3),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: 3,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.large - 3),
          child: Column(
            children: List.generate(_gridSize, (r) {
              return Expanded(
                child: Row(
                  children: List.generate(_gridSize, (c) {
                    return Expanded(
                      child: _buildCell(r * _gridSize + c),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    final foundColor = _foundCellColors[index];
    final foundRadius = _foundCellRadii[index];

    final isPreview = _previewPath.contains(index);
    final isPreviewStart = _dragStartIndex == index;
    final isHint = _hintCells.contains(index) && foundColor == null;

    // Determine preview radius (head/tail rounding during drag).
    BorderRadius? previewRadius;
    if (isPreview) {
      final i = _previewPath.indexOf(index);
      if (_previewValid) {
        previewRadius = _radiusForPathPosition(_previewPath, i);
      }
    }

    Color bg;
    Color fg;
    Color border;
    BorderRadius? radius = foundRadius ?? previewRadius ?? BorderRadius.zero;

    if (foundColor != null) {
      bg = foundColor.withValues(alpha: 0.42);
      fg = Colors.white;
      border = foundColor;
    } else if (isPreview && _previewValid) {
      bg = _palette[0].withValues(alpha: isPreviewStart ? 0.60 : 0.35);
      fg = Colors.white;
      border = _palette[0];
    } else if (isPreview && !_previewValid) {
      bg = AppColors.accentCoral.withValues(alpha: 0.35);
      fg = Colors.white;
      border = AppColors.accentCoral;
    } else if (isHint) {
      bg = AppColors.accentYellow.withValues(alpha: 0.25);
      fg = AppColors.textYellow;
      border = AppColors.accentYellow;
    } else {
      bg = AppColors.surface;
      fg = AppColors.textPrimary;
      border = AppColors.border;
      radius = BorderRadius.zero;
    }

    final r = index ~/ _gridSize;
    final c = index % _gridSize;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: border, width: 0.5),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              _cells[r][c],
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: fg,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBigStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════
// Data classes
// ═══════════════════════════════════════════════════════════════

class _GridResult {
  final List<List<String>> cells;
  final List<_PlacedWord> placedWords;
  _GridResult({required this.cells, required this.placedWords});
}

class _PlacedWord {
  final String word;
  final int wordId;
  final String audioAsset;
  final int startRow;
  final int startCol;
  final int dRow;
  final int dCol;

  _PlacedWord({
    required this.word,
    required this.wordId,
    required this.audioAsset,
    required this.startRow,
    required this.startCol,
    required this.dRow,
    required this.dCol,
  });

  List<int> path(int gridSize) {
    final result = <int>[];
    for (int i = 0; i < word.length; i++) {
      final r = startRow + dRow * i;
      final c = startCol + dCol * i;
      result.add(r * gridSize + c);
    }
    return result;
  }
}