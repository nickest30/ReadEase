import 'dart:async';

class HintService {
  int _remaining = 3;
  bool _onCooldown = false;
  Timer? _cooldownTimer;

  int get remaining => _remaining;
  bool get onCooldown => _onCooldown;

  bool canUse() => _remaining > 0 && !_onCooldown;

  void use() {
    if (!canUse()) return;
    _remaining--;
    _onCooldown = true;
    _cooldownTimer = Timer(const Duration(seconds: 10), () {
      _onCooldown = false;
    });
  }

  void reset() {
    _remaining = 3;
    _onCooldown = false;
    _cooldownTimer?.cancel();
  }

  void dispose() {
    _cooldownTimer?.cancel();
  }
}