import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:powersync/powersync.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService extends PowerSyncBackendConnector {
  SupabaseClient get client => Supabase.instance.client;

  SupabaseService();

  static Future<void> init() async {
    final url = dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true 
        ? dotenv.env['SUPABASE_URL']! 
        : 'https://jgcodpaztgpoiithqrad.supabase.co';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty == true 
        ? dotenv.env['SUPABASE_ANON_KEY']! 
        : 'sb_publishable_BWNOdxaXJC49mX-ZbQ6cPw_ikVAc4nJ';

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      debugPrint('Supabase inicializado correctamente.');
    } catch (e) {
      debugPrint('Aviso o error inicializando Supabase: $e');
    }
  }

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) return null;
      return PowerSyncCredentials(
        endpoint: dotenv.env['POWERSYNC_URL'] ?? 'https://6a8de23b8453e7cf8331940a.powersync.com',
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
      // Coerce booleanos para compatibilidad con tipos bool de Postgres
      if (payload['es_principal'] is int) {
        payload['es_principal'] = payload['es_principal'] == 1;
      }
      if (payload['is_deleted'] is int) {
        payload['is_deleted'] = payload['is_deleted'] == 1;
      }
      // Asegurar que la dirección completa esté poblada
      if (!payload.containsKey('direccion') || payload['direccion'] == null || (payload['direccion'] as String).isEmpty) {
        final tipo = payload['tipo_via'] ?? '';
        final num = payload['numero_via'] ?? '';
        final brr = payload['barrio'] ?? '';
        final ciu = payload['ciudad'] ?? '';
        final parts = <String>[
          if (tipo.toString().isNotEmpty && num.toString().isNotEmpty) '$tipo $num',
          if (brr.toString().isNotEmpty) 'Barrio $brr',
          if (ciu.toString().isNotEmpty) ciu.toString(),
        ];
        payload['direccion'] = parts.join(', ');
      }
      await client.from('personas').upsert(payload);
      debugPrint('uploadPersona a Supabase completado para cedula: ${payload['cedula']}');
      return true;
    } catch (e) {
      debugPrint('Error en uploadPersona Supabase: $e');
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
