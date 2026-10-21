import 'dart:async';

/// Tracks per-session hint usage for games.
/// Grants [_maxHints] hints per session, each triggering a brief cooldown
/// so young learners can't spam the hint button.
///
/// Note: this is NOT a ChangeNotifier. The calling game screen is
/// responsible for rebuilding after [use] or [reset] so the UI reflects
/// the new remaining count and cooldown state.
class HintService {
  static const int _maxHints = 3;
  static const Duration _cooldownDuration = Duration(seconds: 10);

  int _remaining = _maxHints;
  bool _onCooldown = false;
  Timer? _cooldownTimer;

  int get remaining => _remaining;
  bool get onCooldown => _onCooldown;

  bool canUse() => _remaining > 0 && !_onCooldown;

  void use() {
    if (!canUse()) return;
    _remaining--;
    _onCooldown = true;
    _cooldownTimer = Timer(_cooldownDuration, () {
      _onCooldown = false;
    });
  }

  void reset() {
    _remaining = _maxHints;
    _onCooldown = false;
    _cooldownTimer?.cancel();
  }

  void dispose() {
    _cooldownTimer?.cancel();
  }
}