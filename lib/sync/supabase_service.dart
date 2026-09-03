import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:powersync/powersync.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService extends PowerSyncBackendConnector {
  SupabaseClient get client => Supabase.instance.client;

  SupabaseService();

  static Future<void> init() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty) {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
    }
  }

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) return null;
      return PowerSyncCredentials(
        endpoint: dotenv.env['POWERSYNC_URL'] ?? '',
        token: session.accessToken,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (var crud in transaction.crud) {
        final table = client.from(crud.table);
        if (crud.op == UpdateType.put) {
          await table.upsert(crud.opData!);
        } else if (crud.op == UpdateType.patch) {
          await table.update(crud.opData!).eq('id', crud.id);
        } else if (crud.op == UpdateType.delete) {
          await table.delete().eq('id', crud.id);
        }
      }
      await transaction.complete();
    } catch (e) {
      // Si hay un error, el registro permanecerá en la cola de CRUD para reintentar más tarde.
    }
  }

  /// Sincronización directa individual a Supabase
  Future<bool> uploadPersona(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      // Remove local-only flags if necessary
      await client.from('personas').upsert(payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Eliminar persona por cédula en Supabase
  Future<bool> deletePersonaByCedula(String cedula) async {
    try {
      await client.from('personas').delete().eq('cedula', cedula);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Eliminar todas las personas en Supabase
  Future<bool> deleteAllPersonas() async {
    try {
      await client.from('personas').delete().neq('id', '');
      return true;
    } catch (e) {
      return false;
    }
  }
}
