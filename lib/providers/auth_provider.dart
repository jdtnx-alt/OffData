import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';
import '../repositories/usuario_repository.dart';

class AuthProvider extends ChangeNotifier {
  static const String _kIsLoggedIn = 'auth_is_logged_in';
  static const String _kUserJson = 'auth_user_json';

  // Credenciales por defecto
  static const String defaultEmail = UsuarioRepository.adminEmail;
  static const String defaultPassword = UsuarioRepository.adminPassword;

  static const String encuestador1Email = UsuarioRepository.encuestador1Email;
  static const String encuestador1Password = UsuarioRepository.encuestador1Password;

  static const String encuestador2Email = UsuarioRepository.encuestador2Email;
  static const String encuestador2Password = UsuarioRepository.encuestador2Password;

  bool _isLoggedIn = false;
  Usuario? _currentUser;
  bool _initialized = false;
  final UsuarioRepository _usuarioRepo = UsuarioRepository();

  bool get isLoggedIn => _isLoggedIn;
  bool get initialized => _initialized;
  Usuario? get currentUser => _currentUser;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isEncuestador => _currentUser?.isEncuestador ?? false;

  String get userId => _currentUser?.id ?? '';
  String get email => _currentUser?.email ?? '';
  String get name => _currentUser?.nombre ?? '';
  String get phone => _currentUser?.telefono ?? '';
  String get role => _currentUser?.rol ?? 'encuestador';

  AuthProvider() {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_kIsLoggedIn) ?? false;
      final userJson = prefs.getString(_kUserJson);

      if (_isLoggedIn && userJson != null) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = Usuario.fromMap(map);
      } else {
        _isLoggedIn = false;
        _currentUser = null;
      }
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

    try {
      final user = await _usuarioRepo.autenticar(cleanEmail, cleanPass);
      if (user != null) {
        _currentUser = user;
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kIsLoggedIn, true);
        await prefs.setString(_kUserJson, jsonEncode(user.toMap()));

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error en login: $e');
    }
    return false;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, false);
    await prefs.remove(_kUserJson);
    notifyListeners();
  }

  Future<bool> changePassword(String currentPass, String newPass) async {
    if (_currentUser == null) return false;
    if (currentPass.trim() != _currentUser!.password) {
      return false;
    }

    final updated = _currentUser!.copyWith(password: newPass.trim());
    await _usuarioRepo.updateUsuario(updated);
    _currentUser = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserJson, jsonEncode(updated.toMap()));
    notifyListeners();
    return true;
  }

  Future<void> updateProfile({required String newName, required String newPhone}) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(nombre: newName.trim(), telefono: newPhone.trim());
    await _usuarioRepo.updateUsuario(updated);
    _currentUser = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserJson, jsonEncode(updated.toMap()));
    notifyListeners();
  }
}
