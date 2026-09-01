import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  static const String _kIsLoggedIn = 'auth_is_logged_in';
  static const String _kEmail = 'auth_user_email';
  static const String _kPassword = 'auth_user_password';
  static const String _kName = 'auth_user_name';
  static const String _kPhone = 'auth_user_phone';

  // Credenciales por defecto
  static const String defaultEmail = 'admin@offdata.com';
  static const String defaultPassword = 'OffData2026*';
  static const String defaultName = 'Juan David';
  static const String defaultPhone = '300 123 4567';

  bool _isLoggedIn = false;
  String _email = defaultEmail;
  String _name = defaultName;
  String _phone = defaultPhone;
  String _password = defaultPassword;
  bool _initialized = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get initialized => _initialized;
  String get email => _email;
  String get name => _name;
  String get phone => _phone;

  AuthProvider() {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_kIsLoggedIn) ?? false;
      _email = prefs.getString(_kEmail) ?? defaultEmail;
      _password = prefs.getString(_kPassword) ?? defaultPassword;
      _name = prefs.getString(_kName) ?? defaultName;
      _phone = prefs.getString(_kPhone) ?? defaultPhone;
    } catch (e) {
      debugPrint('Error loading auth state: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String inputEmail, String inputPassword) async {
    final cleanEmail = inputEmail.trim().toLowerCase();
    final cleanPass = inputPassword.trim();

    if (cleanEmail == _email.toLowerCase() && cleanPass == _password) {
      _isLoggedIn = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsLoggedIn, true);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, false);
    notifyListeners();
  }

  Future<bool> changePassword(String currentPass, String newPass) async {
    if (currentPass.trim() != _password) {
      return false;
    }
    _password = newPass.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPassword, _password);
    notifyListeners();
    return true;
  }

  Future<void> updateProfile({required String newName, required String newPhone}) async {
    _name = newName.trim();
    _phone = newPhone.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, _name);
    await prefs.setString(_kPhone, _phone);
    notifyListeners();
  }
}
