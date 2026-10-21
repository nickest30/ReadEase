import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyTextScale = 'settings.textScale';
  static const _keyAudioEnabled = 'settings.audioEnabled';
  static const _keySfxEnabled = 'settings.sfxEnabled';
  static const _keySfxVolume = 'settings.sfxVolume';
  static const _keyBgmVolume = 'settings.bgmVolume';
  static const _keyColorBlindMode = 'settings.colorBlindMode';

  double _textScale = 1.0;
  bool _audioEnabled = true;
  bool _sfxEnabled = true;
  double _sfxVolume = 1.0;
  double _bgmVolume = 0.5;
  String _colorBlindMode = 'none';

  double get textScale => _textScale;
  bool get audioEnabled => _audioEnabled;
  bool get sfxEnabled => _sfxEnabled;
  double get sfxVolume => _sfxVolume;
  double get bgmVolume => _bgmVolume;
  String get colorBlindMode => _colorBlindMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _textScale = prefs.getDouble(_keyTextScale) ?? 1.0;
    _audioEnabled = prefs.getBool(_keyAudioEnabled) ?? true;
    _sfxEnabled = prefs.getBool(_keySfxEnabled) ?? _audioEnabled;
    _sfxVolume = prefs.getDouble(_keySfxVolume) ?? 1.0;
    _bgmVolume = prefs.getDouble(_keyBgmVolume) ?? 0.5;
    _colorBlindMode = prefs.getString(_keyColorBlindMode) ?? 'none';
    
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    _textScale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTextScale, value);
  }

  Future<void> setAudioEnabled(bool value) async {
    _audioEnabled = value;
    if (!value) _sfxEnabled = false;
    
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAudioEnabled, value);
    await prefs.setBool(_keySfxEnabled, _sfxEnabled);
  }

  Future<void> setSfxEnabled(bool value) async {
    _sfxEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySfxEnabled, value);
  }

  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySfxVolume, value);
  }

  Future<void> setBgmVolume(double value) async {
    _bgmVolume = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBgmVolume, value);
  }

  Future<void> setColorBlindMode(String mode) async {
    _colorBlindMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyColorBlindMode, mode);
  }
}