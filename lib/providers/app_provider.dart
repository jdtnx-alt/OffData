import 'package:flutter/material.dart';
import 'package:offdata/models/persona.dart';
import 'package:offdata/repositories/persona_repository.dart';
import 'package:powersync/powersync.dart';
import 'package:offdata/database/app_database.dart';

class AppProvider extends ChangeNotifier {
  final PersonaRepository _personaRepo = PersonaRepository();
  List<Persona> _personas = [];
  bool _isLoading = false;
  SyncStatus? _syncStatus;

  List<Persona> get personas => _personas;
  bool get isLoading => _isLoading;
  SyncStatus? get syncStatus => _syncStatus;

  AppProvider() {
    _init();
  }

  void _init() {
    _personaRepo.watchPersonas().listen((data) {
      _personas = data;
      notifyListeners();
    });

    AppDatabase().db.statusStream.listen((status) {
      _syncStatus = status;
      notifyListeners();
    });
  }

  Future<void> addPersona(Persona persona) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _personaRepo.savePersona(persona);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkDuplicate(String cedula) async {
    final persona = await _personaRepo.getPersonaByCedula(cedula);
    return persona != null;
  }

  // Real-time metrics placeholder
  int get totalPersonas => _personas.length;
}
