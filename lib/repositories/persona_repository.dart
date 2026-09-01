import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/persona.dart';
import '../models/persona_historial.dart';
import '../sync/supabase_service.dart';

class PersonaRepository {
  final PowerSyncDatabase _db = AppDatabase().db;
  final _uuid = const Uuid();
  final _supabaseService = SupabaseService();

  /// Escucha solo los registros PRINCIPALES (uno por cédula)
  Stream<List<Persona>> watchPersonas() {
    return _db.watch(
      'SELECT * FROM personas WHERE is_deleted = 0 AND es_principal = 1 ORDER BY updated_at DESC',
    ).map((rows) => rows.map((r) => Persona.fromMap(r)).toList());
  }

  /// Escucha todos los registros que fueron creados/editados OFFLINE y están pendientes de sincronizar
  Stream<List<Persona>> watchOfflinePersonas() {
    return _db.watch(
      'SELECT * FROM personas WHERE is_deleted = 0 AND is_synced = 0 ORDER BY updated_at DESC',
    ).map((rows) => rows.map((r) => Persona.fromMap(r)).toList());
  }

  /// Todas las versiones registradas para una cédula (historial de registros)
  Future<List<Persona>> getAllVersionesByCedula(String cedula) async {
    final rows = await _db.getAll(
      'SELECT * FROM personas WHERE cedula = ? AND is_deleted = 0 ORDER BY registro_numero DESC',
      [cedula],
    );
    return rows.map((r) => Persona.fromMap(r)).toList();
  }

  Future<Persona?> getPersonaById(String id) async {
    final result = await _db.getOptional('SELECT * FROM personas WHERE id = ?', [id]);
    return result != null ? Persona.fromMap(result) : null;
  }

  /// Retorna el registro PRINCIPAL para una cédula (si existe)
  Future<Persona?> getPersonaByCedula(String cedula) async {
    final result = await _db.getOptional(
      'SELECT * FROM personas WHERE cedula = ? AND is_deleted = 0 AND es_principal = 1 LIMIT 1',
      [cedula],
    );
    return result != null ? Persona.fromMap(result) : null;
  }

  /// Historial de cambios para una cédula
  Future<List<PersonaHistorial>> getHistorialByCedula(String cedula) async {
    final rows = await _db.getAll(
      'SELECT * FROM personas_historial WHERE cedula = ? ORDER BY fecha DESC',
      [cedula],
    );
    return rows.map((r) => PersonaHistorial.fromMap({...r, 'id': r['id'] ?? _uuid.v4()})).toList();
  }

  /// Guardar nueva persona (primer registro, is_synced = 0 por defecto)
  Future<void> savePersona(Persona persona) async {
    await _db.writeTransaction((tx) async {
      await tx.execute(
        '''INSERT OR REPLACE INTO personas 
           (id, cedula, nombre_completo, fecha_nacimiento, tipo_via, numero_via, barrio, ciudad, telefono,
            es_principal, registro_numero, sync_version, is_synced, created_at, updated_at, device_id, is_deleted)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          persona.id,
          persona.cedula,
          persona.nombreCompleto,
          persona.fechaNacimiento,
          persona.tipoVia,
          persona.numeroVia,
          persona.barrio,
          persona.ciudad,
          persona.telefono,
          persona.esPrincipal ? 1 : 0,
          persona.registroNumero,
          persona.syncVersion,
          persona.isSynced ? 1 : 0,
          persona.createdAt.toIso8601String(),
          persona.updatedAt.toIso8601String(),
          persona.deviceId,
          persona.isDeleted ? 1 : 0,
        ],
      );
    });
  }

  /// Actualizar datos de persona existente y guardar historial de cambios
  Future<void> actualizarConHistorial({
    required Persona existente,
    required Persona nueva,
  }) async {
    await _db.writeTransaction((tx) async {
      // 1. Marcar la persona existente como NO principal
      await tx.execute(
        'UPDATE personas SET es_principal = 0 WHERE cedula = ?',
        [existente.cedula],
      );

      // 2. Insertar nuevo registro como principal
      final nuevoRegistroNum = existente.registroNumero + 1;
      final personaNueva = Persona(
        id: nueva.id,
        cedula: existente.cedula,
        nombreCompleto: existente.nombreCompleto,  // inmutable
        fechaNacimiento: existente.fechaNacimiento, // inmutable
        tipoVia: nueva.tipoVia,
        numeroVia: nueva.numeroVia,
        barrio: nueva.barrio,
        ciudad: nueva.ciudad,
        telefono: nueva.telefono,
        esPrincipal: true,
        registroNumero: nuevoRegistroNum,
        syncVersion: existente.syncVersion + 1,
        isSynced: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deviceId: nueva.deviceId,
      );

      await tx.execute(
        '''INSERT INTO personas 
           (id, cedula, nombre_completo, fecha_nacimiento, tipo_via, numero_via, barrio, ciudad, telefono,
            es_principal, registro_numero, sync_version, is_synced, created_at, updated_at, device_id, is_deleted)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          personaNueva.id,
          personaNueva.cedula,
          personaNueva.nombreCompleto,
          personaNueva.fechaNacimiento,
          personaNueva.tipoVia,
          personaNueva.numeroVia,
          personaNueva.barrio,
          personaNueva.ciudad,
          personaNueva.telefono,
          1,
          personaNueva.registroNumero,
          personaNueva.syncVersion,
          0,
          personaNueva.createdAt.toIso8601String(),
          personaNueva.updatedAt.toIso8601String(),
          personaNueva.deviceId,
          0,
        ],
      );

      // 3. Registrar cambios en historial
      final camposAComparar = {
        'tipo_via': (existente.tipoVia, nueva.tipoVia),
        'numero_via': (existente.numeroVia, nueva.numeroVia),
        'barrio': (existente.barrio, nueva.barrio),
        'ciudad': (existente.ciudad, nueva.ciudad),
        'telefono': (existente.telefono, nueva.telefono),
      };

      for (final entry in camposAComparar.entries) {
        final (anterior, nuevoVal) = entry.value;
        if (anterior != nuevoVal) {
          await tx.execute(
            '''INSERT INTO personas_historial (id, persona_id, cedula, campo, valor_anterior, valor_nuevo, fecha)
               VALUES (?, ?, ?, ?, ?, ?, ?)''',
            [
              const Uuid().v4(),
              personaNueva.id,
              existente.cedula,
              entry.key,
              anterior,
              nuevoVal,
              DateTime.now().toIso8601String(),
            ],
          );
        }
      }
    });
  }

  /// Sincronizar un registro individual manualmente
  Future<bool> sincronizarPersonaManual(Persona persona) async {
    final ok = await _supabaseService.uploadPersona(persona.toMap());
    // Marcamos como sincronizado localmente
    await _db.writeTransaction((tx) async {
      await tx.execute('UPDATE personas SET is_synced = 1 WHERE id = ?', [persona.id]);
    });
    return ok;
  }

  /// Sincronizar todos los registros offline pendientes manualmente
  Future<int> sincronizarTodosManual() async {
    final offlineRows = await _db.getAll(
      'SELECT * FROM personas WHERE is_deleted = 0 AND is_synced = 0',
    );
    int count = 0;
    for (final row in offlineRows) {
      final p = Persona.fromMap(row);
      await _supabaseService.uploadPersona(p.toMap());
      await _db.writeTransaction((tx) async {
        await tx.execute('UPDATE personas SET is_synced = 1 WHERE id = ?', [p.id]);
      });
      count++;
    }
    return count;
  }

  Future<void> deletePersona(String id) async {
    await _db.writeTransaction((tx) async {
      await tx.execute(
        'UPDATE personas SET is_deleted = 1, updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );
    });
  }

  /// Estadísticas locales (siempre disponibles offline)
  Future<Map<String, dynamic>> getEstadisticas() async {
    final now = DateTime.now();
    final hoyInicio = DateTime(now.year, now.month, now.day).toIso8601String();
    final semanaInicio = now.subtract(const Duration(days: 7)).toIso8601String();
    final mesInicio = DateTime(now.year, now.month, 1).toIso8601String();

    final total = await _db.getOptional(
      'SELECT COUNT(DISTINCT cedula) as count FROM personas WHERE is_deleted = 0',
    );
    final hoy = await _db.getOptional(
      'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND es_principal = 1 AND created_at >= ?',
      [hoyInicio],
    );
    final semana = await _db.getOptional(
      'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND es_principal = 1 AND created_at >= ?',
      [semanaInicio],
    );
    final mes = await _db.getOptional(
      'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND es_principal = 1 AND created_at >= ?',
      [mesInicio],
    );
    final conActualizaciones = await _db.getOptional(
      'SELECT COUNT(DISTINCT cedula) as count FROM personas WHERE is_deleted = 0 AND registro_numero > 1',
    );
    final pendientesSync = await _db.getOptional(
      'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND is_synced = 0',
    );
    final ultimoRegistro = await _db.getOptional(
      'SELECT nombre_completo, cedula, created_at FROM personas WHERE is_deleted = 0 ORDER BY created_at DESC LIMIT 1',
    );

    return {
      'total': total?['count'] ?? 0,
      'hoy': hoy?['count'] ?? 0,
      'semana': semana?['count'] ?? 0,
      'mes': mes?['count'] ?? 0,
      'con_actualizaciones': conActualizaciones?['count'] ?? 0,
      'pendientes_sync': pendientesSync?['count'] ?? 0,
      'ultimo_nombre': ultimoRegistro?['nombre_completo'] ?? '-',
      'ultimo_cedula': ultimoRegistro?['cedula'] ?? '',
      'ultimo_fecha': ultimoRegistro?['created_at'] ?? '',
    };
  }
}
