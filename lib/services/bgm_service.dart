import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/settings_provider.dart';

enum BgmTrack { main, relax, lesson, game }

class BgmService {
  static final _player = AudioPlayer();
  static SettingsProvider? _settings;
  static BgmTrack? _currentTrack;
  static bool _isPausedByLifecycle = false;

  static void init(SettingsProvider provider) {
    _settings = provider;
    _player.setReleaseMode(ReleaseMode.loop);
    _settings?.addListener(_onSettingsChanged);
  }

  static void _onSettingsChanged() {
    if (_settings == null) return;
    
    if (_settings!.bgmVolume <= 0) {
      _player.pause();
    } else {
      if (_player.state == PlayerState.paused && !_isPausedByLifecycle) {
        _player.resume();
      }
      _updateVolume();
    }
  }

  static void _updateVolume() {
    if (_settings == null) return;
    final volume = _settings!.bgmVolume * 0.25; // Hard cap at 25% for subtlety
    _player.setVolume(volume);
  }

  static Future<void> playTrack(BgmTrack track) async {
    if (_settings == null) return;
    
    if (_settings!.bgmVolume <= 0) {
      await _player.stop();
      _currentTrack = track;
      return;
    }

    if (_currentTrack == track && _player.state == PlayerState.playing) return;

    _currentTrack = track;
    String fileName;
    switch (track) {
      case BgmTrack.main: fileName = 'bgm_main.mp3'; break;
      case BgmTrack.relax: fileName = 'bgm_relax.mp3'; break;
      case BgmTrack.lesson: fileName = 'bgm_lesson.mp3'; break;
      case BgmTrack.game: fileName = 'bgm_game.mp3'; break;
    }

    try {
      await _player.stop();
      await _player.play(AssetSource('audio/bgm/$fileName'));
      _updateVolume();
    } catch (e) {
      debugPrint('❌ BGM ERROR ($fileName): $e');
    }
  }

  static void pauseForLifecycle() {
    _isPausedByLifecycle = true;
    _player.pause();
  }

  static void resumeFromLifecycle() {
    _isPausedByLifecycle = false;
    if (_settings != null && _settings!.bgmVolume > 0) {
      _player.resume();
    }
  }

  static Future<void> stop() async {
    await _player.stop();
    _currentTrack = null;
  }
  
  static void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    _player.dispose();
  }
}