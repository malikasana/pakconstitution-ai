import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontSize { normal, large, xlarge }

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  AppFontSize _fontSize = AppFontSize.normal;
  bool _showReferenceCards = true;
  bool _compactView = false;
  bool _showTypingIndicator = true;
  int _contextTurns = 3;
  String _apiUrl = ''; // Single source of truth — no hardcoded default

  ThemeMode get themeMode => _themeMode;
  AppFontSize get fontSize => _fontSize;
  bool get showReferenceCards => _showReferenceCards;
  bool get compactView => _compactView;
  bool get showTypingIndicator => _showTypingIndicator;
  int get contextTurns => _contextTurns;
  bool get isDark => _themeMode == ThemeMode.dark;
  String get apiUrl => _apiUrl;

  double get baseFontSize {
    switch (_fontSize) {
      case AppFontSize.large:
        return 15.0;
      case AppFontSize.xlarge:
        return 17.0;
      case AppFontSize.normal:
      default:
        return 13.5;
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = (prefs.getString('theme') ?? 'light') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    _fontSize = AppFontSize.values[prefs.getInt('fontSize') ?? 0];
    _showReferenceCards = prefs.getBool('showRefs') ?? true;
    _compactView = prefs.getBool('compactView') ?? false;
    _showTypingIndicator = prefs.getBool('showTyping') ?? true;
    _contextTurns = prefs.getInt('contextTurns') ?? 3;
    _apiUrl = prefs.getString('apiUrl') ?? ''; // Empty until user sets it
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  void toggleTheme() {
    setTheme(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setFontSize(AppFontSize size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fontSize', size.index);
    notifyListeners();
  }

  Future<void> setShowReferenceCards(bool val) async {
    _showReferenceCards = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRefs', val);
    notifyListeners();
  }

  Future<void> setCompactView(bool val) async {
    _compactView = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('compactView', val);
    notifyListeners();
  }

  Future<void> setShowTypingIndicator(bool val) async {
    _showTypingIndicator = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTyping', val);
    notifyListeners();
  }

  Future<void> setContextTurns(int val) async {
    _contextTurns = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('contextTurns', val);
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    _apiUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiUrl', _apiUrl);
    notifyListeners();
  }
}