class GameScore {
  final int passageCorrect;
  final int passageTotal;
  final int gameCorrect;
  final int gameTotal;

  const GameScore({
    this.passageCorrect = 0,
    this.passageTotal = 0,
    required this.gameCorrect,
    required this.gameTotal,
  });

  factory GameScore.fromArgs(
    Map args, {
    required int gameCorrect,
    required int gameTotal,
  }) {
    return GameScore(
      passageCorrect: (args['passageCorrect'] as int?) ?? 0,
      passageTotal: (args['passageTotal'] as int?) ?? 0,
      gameCorrect: gameCorrect,
      gameTotal: gameTotal,
    );
  }

  int get correct => passageCorrect + gameCorrect;
  int get total => passageTotal + gameTotal;

  /// Whether the passage was already answered this session.
  bool get hasPassage => passageTotal > 0;
}