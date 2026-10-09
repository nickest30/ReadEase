/// Central SFX hookup for game screens.
///
/// Real audio files arrive in M5.5. Until then, all methods are no-ops.
/// When SFX land, replace each body with an audioplayers call:
///
///   await _player.play(AssetSource('audio/sfx/sparkle.mp3'));
class GameSfx {
  static final GameSfx instance = GameSfx._();
  GameSfx._();

  Future<void> playCorrect() async {
    // M5.5 hook: sparkle.mp3
  }

  Future<void> playWrong() async {
    // M5.5 hook: whoosh.mp3
  }

  Future<void> playBadgeUnlock() async {
    // M5.5 hook: badge_unlock.mp3
  }

  Future<void> playCelebration() async {
    // M5.5 hook: celebration.mp3
  }
}