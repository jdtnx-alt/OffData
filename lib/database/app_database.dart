import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'schema.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  late final PowerSyncDatabase db;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  Future<void> initialize() async {
    final dir = await getApplicationSupportDirectory();
    final path = join(dir.path, 'offdata.db');

    db = PowerSyncDatabase(schema: schema, path: path);
    await db.initialize();
  }
}
