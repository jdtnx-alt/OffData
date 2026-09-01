import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart';
import '../database/app_database.dart';
import 'supabase_service.dart';

class SyncController extends ChangeNotifier {
  final PowerSyncDatabase _db = AppDatabase().db;
  SyncStatus? _status;
  bool _hasInternet = false;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _statusSub;

  SyncStatus? get status => _status;
  bool get hasInternet => _hasInternet;
  // Solo se muestra sincronizando cuando hay una operación de subida manual o activa en curso
  bool get isSyncing => _isSyncing;
  bool get isConnected => _hasInternet;

  SyncController() {
    _initConnectivity();
    _statusSub = _db.statusStream.listen((status) {
      _status = status;
      notifyListeners();
    });
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    _updateInternetStatus(results);

    _connectivitySub = connectivity.onConnectivityChanged.listen((results) {
      _updateInternetStatus(results);
    });
  }

  void _updateInternetStatus(List<ConnectivityResult> results) {
    final hasNet = results.any((r) => r != ConnectivityResult.none);
    if (_hasInternet != hasNet) {
      _hasInternet = hasNet;
      if (_hasInternet) {
        connect();
      }
      notifyListeners();
    }
  }

  Future<void> connect() async {
    try {
      final connector = SupabaseService();
      await _db.connect(connector: connector);
    } catch (e) {
      debugPrint('SyncController connect: $e');
    }
  }

  Future<void> setSyncing(bool syncing) async {
    _isSyncing = syncing;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!_hasInternet) return;
    _isSyncing = true;
    notifyListeners();
    try {
      final connector = SupabaseService();
      await connector.uploadData(_db);
    } catch (e) {
      debugPrint('Manual sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _db.disconnect();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
