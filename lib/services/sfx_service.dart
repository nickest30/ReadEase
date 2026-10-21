import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/settings_provider.dart';

class SfxService {
  static final _player = AudioPlayer();
  static SettingsProvider? _settings;

  static void init(SettingsProvider provider) {
    _settings = provider;
    
    // Configure strictly for Android
    _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          audioMode: AndroidAudioMode.normal,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
  }

  static Future<void> _play(String file) async {
    try {
      if (_settings != null) {
        if (!_settings!.sfxEnabled || !_settings!.audioEnabled) return;
      }
      
      await _player.stop(); // Stop previous sound
      
      if (_settings != null) {
        await _player.setVolume(_settings!.sfxVolume); // Apply volume
      }
      
      // Play the asset
      await _player.play(AssetSource('audio/sfx/$file'));
      
    } catch (e) {
      // THIS WILL PRINT IN YOUR TERMINAL IF THE FILE IS MISSING OR CORRUPT
      debugPrint('❌ SFX ERROR ($file): $e'); 
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