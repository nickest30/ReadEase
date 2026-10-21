import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyTextScale = 'settings.textScale';
  static const _keySfxVolume = 'settings.sfxVolume';
  static const _keyBgmVolume = 'settings.bgmVolume';
  static const _keyColorBlindMode = 'settings.colorBlindMode';

  double _textScale = 1.0;
  double _sfxVolume = 1.0;
  double _bgmVolume = 0.3;
  String _colorBlindMode = 'none';

  double get textScale => _textScale;
  double get sfxVolume => _sfxVolume;
  double get bgmVolume => _bgmVolume;
  String get colorBlindMode => _colorBlindMode;

  bool get sfxEnabled => _sfxVolume > 0;
  bool get bgmEnabled => _bgmVolume > 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _textScale = prefs.getDouble(_keyTextScale) ?? 1.0;
    _sfxVolume = prefs.getDouble(_keySfxVolume) ?? 1.0;
    _bgmVolume = prefs.getDouble(_keyBgmVolume) ?? 0.3;
    _colorBlindMode = prefs.getString(_keyColorBlindMode) ?? 'none';

    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    _textScale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTextScale, value);
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