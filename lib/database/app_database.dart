import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'schema.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  PowerSyncDatabase? _db;

  PowerSyncDatabase get db {
    if (_db == null) {
      throw StateError('AppDatabase no ha sido inicializada aún.');
    }
    return _db!;
  }

  bool get isInitialized => _db != null;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  Future<void> initialize() async {
    if (_db != null) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final path = join(dir.path, 'offdata.db');

      final instance = PowerSyncDatabase(schema: schema, path: path);
      await instance.initialize();
      _db = instance;
    } catch (e) {
      debugPrint('Error en AppDatabase.initialize(): $e');
      rethrow;
    }
  }
}
