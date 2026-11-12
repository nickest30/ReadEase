import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/settings_provider.dart';

class SfxService {
  static final _player = AudioPlayer();
  static SettingsProvider? _settings;

  static void init(SettingsProvider provider) {
    _settings = provider;
    _player.setVolume(provider.sfxVolume);
    _settings?.addListener(_onVolumeChanged);
  }

  static void _onVolumeChanged() {
    _player.setVolume(_settings?.sfxVolume ?? 1.0);
  }

  static Future<void> _play(String file) async {
    try {
      if (_settings != null && _settings!.sfxVolume <= 0) return;

      // No setVolume() here — set once in init + listener.
      // audioplayers automatically interrupts the current sound
      // when play() is called, so rapid taps never queue.
      await _player.play(AssetSource('audio/sfx/$file'));
    } catch (e) {
      debugPrint('SFX failed ($file): $e');
    }
  }

  static Future<void> tap() => _play('sfx_tap.mp3');
  static Future<void> correct() => _play('sfx_correct.mp3');
  static Future<void> wrong() => _play('sfx_wrong.mp3');
  static Future<void> fail() => _play('sfx_fail.mp3');
  static Future<void> celebration() => _play('sfx_celebration.mp3');
  static Future<void> transition() => _play('sfx_transition.mp3');
  static Future<void> unlock() => _play('sfx_unlock.mp3');
}