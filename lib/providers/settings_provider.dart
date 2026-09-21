import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyTextScale = 'settings.textScale';
  static const _keyAudioEnabled = 'settings.audioEnabled';
  static const _keyColorBlindMode = 'settings.colorBlindMode';

  double _textScale = 1.0;
  bool _audioEnabled = true;
  String _colorBlindMode = 'none';

  double get textScale => _textScale;
  bool get audioEnabled => _audioEnabled;
  String get colorBlindMode => _colorBlindMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _textScale = prefs.getDouble(_keyTextScale) ?? 1.0;
    _audioEnabled = prefs.getBool(_keyAudioEnabled) ?? true;
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
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAudioEnabled, value);
  }

  Future<void> setColorBlindMode(String mode) async {
    _colorBlindMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyColorBlindMode, mode);
  }
}