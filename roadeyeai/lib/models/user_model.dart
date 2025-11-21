import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel with ChangeNotifier {
  String _email = '';
  bool _isLoggedIn = false;
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _soundAlertsEnabled = true;

  String get email => _email;
  bool get isLoggedIn => _isLoggedIn;
  bool get darkMode => _darkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get soundAlertsEnabled => _soundAlertsEnabled;

  UserModel() {
    _loadPreferences();
  }

  // Load saved preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool('darkMode') ?? false;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    _soundAlertsEnabled = prefs.getBool('soundAlertsEnabled') ?? true;
    notifyListeners();
  }

  void login(String email) {
    _email = email;
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _email = '';
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    notifyListeners();
  }

  Future<void> toggleNotifications() async {
    _notificationsEnabled = !_notificationsEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    notifyListeners();
  }

  Future<void> toggleVibration() async {
    _vibrationEnabled = !_vibrationEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrationEnabled', _vibrationEnabled);
    notifyListeners();
  }

  Future<void> toggleSoundAlerts() async {
    _soundAlertsEnabled = !_soundAlertsEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundAlertsEnabled', _soundAlertsEnabled);
    notifyListeners();
  }
}