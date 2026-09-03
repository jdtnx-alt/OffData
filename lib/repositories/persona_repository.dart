import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/persona.dart';
import '../models/persona_historial.dart';
import '../models/reporte_cambio.dart';
import '../sync/supabase_service.dart';

class PersonaRepository {
  final PowerSyncDatabase _db = AppDatabase().db;
  final _uuid = const Uuid();
  final _supabaseService = SupabaseService();

  /// Escucha los registros sincronizados (is_synced = 1).
  /// Si se especifica [encuestadorId], devuelve las personas encuestadas por ese encuestador (su registro más reciente).
  /// Si es null (Admin), devuelve todas las personas principales de la plataforma.
  /// NOTA: Los registros offline (is_synced = 0) NO aparecen aquí, van a la pestaña de sincronización.
  Stream<List<Persona>> watchPersonas({String? encuestadorId}) {
    if (encuestadorId != null && encuestadorId.isNotEmpty) {
      return _db.watch(
        '''SELECT * FROM personas p1 
           WHERE p1.is_deleted = 0 
             AND p1.is_synced = 1 
             AND p1.encuestador_id = ?
             AND p1.id = (
               SELECT p2.id FROM personas p2 
               WHERE p2.cedula = p1.cedula 
                 AND p2.encuestador_id = ? 
                 AND p2.is_deleted = 0 
                 AND p2.is_synced = 1 
               ORDER BY p2.updated_at DESC LIMIT 1
             )
           ORDER BY p1.updated_at DESC''',
        parameters: [encuestadorId, encuestadorId],
      ).map((rows) => rows.map((r) => Persona.fromMap(r)).toList());
    }
    return _db.watch(
      'SELECT * FROM personas WHERE is_deleted = 0 AND es_principal = 1 AND is_synced = 1 ORDER BY updated_at DESC',
    ).map((rows) => rows.map((r) => Persona.fromMap(r)).toList());
  }

  /// Escucha registros pendientes de sincronizar (is_synced = 0).
  /// Si se especifica [encuestadorId], filtra solo los de ese encuestador.
  Stream<List<Persona>> watchOfflinePersonas({String? encuestadorId}) {
    if (encuestadorId != null && encuestadorId.isNotEmpty) {
      return _db.watch(
        'SELECT * FROM personas WHERE is_deleted = 0 AND is_synced = 0 AND encuestador_id = ? ORDER BY updated_at DESC',
        parameters: [encuestadorId],
      ).map((rows) => rows.map((r) => Persona.fromMap(r)).toList());
    }
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

  /// Obtiene cédulas que tienen 2 o más registros ingresados (duplicados / actualizaciones)
  Future<Set<String>> getCedulasConDuplicados() async {
    final rows = await _db.getAll(
      'SELECT cedula FROM personas WHERE is_deleted = 0 GROUP BY cedula HAVING COUNT(*) > 1',
    );
    return rows.map((r) => r['cedula'] as String).toSet();
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

  /// Verifica si un encuestador específico ya registró una cédula determinada.
  /// Devuelve true si el mismo encuestador ya tiene un registro activo con esa cédula.
  Future<bool> encuestadorYaRegistroCedula(String cedula, String encuestadorId) async {
    final result = await _db.getOptional(
      'SELECT id FROM personas WHERE cedula = ? AND encuestador_id = ? AND is_deleted = 0 LIMIT 1',
      [cedula, encuestadorId],
    );
    return result != null;
  }

  /// Historial de cambios para una cédula
  Future<List<PersonaHistorial>> getHistorialByCedula(String cedula) async {
    final rows = await _db.getAll(
      'SELECT * FROM personas_historial WHERE cedula = ? ORDER BY fecha DESC',
      [cedula],
    );
    return rows.map((r) => PersonaHistorial.fromMap({...r, 'id': r['id'] ?? _uuid.v4()})).toList();
  }

  /// Guardar nueva persona (primer registro)
  Future<void> savePersona(Persona persona) async {
    await _db.writeTransaction((tx) async {
      await tx.execute(
        '''INSERT OR REPLACE INTO personas 
           (id, cedula, nombre_completo, fecha_nacimiento, tipo_via, numero_via, barrio, ciudad, telefono,
            es_principal, registro_numero, sync_version, is_synced, created_at, updated_at, device_id, is_deleted,
            encuestador_id, encuestador_nombre, encuestador_email)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
          persona.encuestadorId,
          persona.encuestadorNombre,
          persona.encuestadorEmail,
        ],
      );
    });
  }

  /// Actualizar datos de persona existente y guardar historial de cambios.
  /// Marca los registros anteriores como SECUNDARIOS (es_principal = 0)
  /// y el nuevo registro como PRINCIPAL (es_principal = 1).
  Future<void> actualizarConHistorial({
    required Persona existente,
    required Persona nueva,
  }) async {
    await _db.writeTransaction((tx) async {
      // 1. Marcar la persona existente como NO principal (secundario)
      await tx.execute(
        'UPDATE personas SET es_principal = 0 WHERE cedula = ?',
        [existente.cedula],
      );

      // 2. Insertar nuevo registro como principal con los datos más recientes
      final nuevoRegistroNum = existente.registroNumero + 1;
      final personaNueva = Persona(
        id: nueva.id,
        cedula: existente.cedula,
        nombreCompleto: existente.nombreCompleto, // inmutable
        fechaNacimiento: existente.fechaNacimiento, // inmutable
        tipoVia: nueva.tipoVia,
        numeroVia: nueva.numeroVia,
        barrio: nueva.barrio,
        ciudad: nueva.ciudad,
        telefono: nueva.telefono,
        esPrincipal: true, // Datos principales (últimos ingresados)
        registroNumero: nuevoRegistroNum,
        syncVersion: existente.syncVersion + 1,
        isSynced: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deviceId: nueva.deviceId,
        encuestadorId: nueva.encuestadorId,
        encuestadorNombre: nueva.encuestadorNombre,
        encuestadorEmail: nueva.encuestadorEmail,
      );

      await tx.execute(
        '''INSERT INTO personas 
           (id, cedula, nombre_completo, fecha_nacimiento, tipo_via, numero_via, barrio, ciudad, telefono,
            es_principal, registro_numero, sync_version, is_synced, created_at, updated_at, device_id, is_deleted,
            encuestador_id, encuestador_nombre, encuestador_email)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
          personaNueva.encuestadorId,
          personaNueva.encuestadorNombre,
          personaNueva.encuestadorEmail,
        ],
      );

      // 3. Registrar cambios en historial con detalle del encuestador que los realizó
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
            '''INSERT INTO personas_historial 
               (id, persona_id, cedula, campo, valor_anterior, valor_nuevo, fecha, encuestador_id, encuestador_nombre)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              const Uuid().v4(),
              personaNueva.id,
              existente.cedula,
              entry.key,
              anterior,
              nuevoVal,
              DateTime.now().toIso8601String(),
              nueva.encuestadorId,
              nueva.encuestadorNombre,
            ],
          );
        }
      }
    });
  }

  /// Obtiene los nombres de todos los encuestadores que han registrado esta cédula
  Future<List<String>> getEncuestadoresPorCedula(String cedula) async {
    try {
      final rows = await _db.getAll(
        'SELECT encuestador_nombre FROM personas WHERE cedula = ? AND is_deleted = 0 AND encuestador_nombre != "" GROUP BY encuestador_nombre ORDER BY MIN(created_at) ASC',
        [cedula],
      );
      return rows.map((r) => (r['encuestador_nombre'] as String? ?? '').trim()).where((n) => n.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  /// Compara los datos entre un registro existente y un nuevo registro.
  /// Retorna un mapa con los campos que cambiaron: campo -> (valor_anterior, valor_nuevo).
  Map<String, (String, String)> compararDatosPersonas(Persona existente, Persona nueva) {
    final campos = <String, (String, String)>{};

    void check(String campo, String anterior, String nuevo) {
      if (anterior.trim().toLowerCase() != nuevo.trim().toLowerCase()) {
        campos[campo] = (anterior.trim(), nuevo.trim());
      }
    }

    check('tipo_via', existente.tipoVia, nueva.tipoVia);
    check('numero_via', existente.numeroVia, nueva.numeroVia);
    check('barrio', existente.barrio, nueva.barrio);
    check('ciudad', existente.ciudad, nueva.ciudad);
    check('telefono', existente.telefono, nueva.telefono);

    return campos;
  }

  /// Guarda una encuesta con toda la lógica requerida:
  /// 1. Si no existe registro previo: lo guarda normalmente (es_principal = 1).
  /// 2. Si ya existe registro de OTRO encuestador:
  ///    a) Si los datos son IDÉNTICOS: se registra localmente para este encuestador (para que aparezca en su lista),
  ///       pero NO se vuelve a subir a Supabase para evitar redundancia de datos.
  ///    b) Si los datos son DIFERENTES: se actualiza con historial, se marca como principal, se sube a Supabase
  ///       si hay internet, y se genera un REPORTE DE CAMBIO para el Administrador.
  Future<Map<String, dynamic>> guardarRegistroEncuesta({
    required Persona nueva,
    required bool isOnline,
  }) async {
    final existente = await getPersonaByCedula(nueva.cedula);

    if (existente == null) {
      // Caso 1: Primer registro de esta persona en la plataforma
      final personaAGuardar = Persona(
        id: nueva.id,
        cedula: nueva.cedula,
        nombreCompleto: nueva.nombreCompleto,
        fechaNacimiento: nueva.fechaNacimiento,
        tipoVia: nueva.tipoVia,
        numeroVia: nueva.numeroVia,
        barrio: nueva.barrio,
        ciudad: nueva.ciudad,
        telefono: nueva.telefono,
        esPrincipal: true,
        registroNumero: 1,
        syncVersion: 1,
        isSynced: isOnline,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deviceId: nueva.deviceId,
        encuestadorId: nueva.encuestadorId,
        encuestadorNombre: nueva.encuestadorNombre,
        encuestadorEmail: nueva.encuestadorEmail,
      );

      await savePersona(personaAGuardar);
      if (isOnline) {
        await sincronizarPersonaManual(personaAGuardar);
      }
      return {'tipo': 'nuevo', 'persona': personaAGuardar};
    }

    // Caso 2: Ya existe un registro previo de esta cédula
    final diferencias = compararDatosPersonas(existente, nueva);

    if (diferencias.isEmpty) {
      // Caso 2A: Datos IDÉNTICOS
      // Se guarda localmente para el nuevo encuestador (con is_synced = 1)
      // para que aparezca en "Mis Registros", pero NO se envía a Supabase (cero redundancia).
      final personaLocal = Persona(
        id: nueva.id,
        cedula: existente.cedula,
        nombreCompleto: existente.nombreCompleto,
        fechaNacimiento: existente.fechaNacimiento,
        tipoVia: existente.tipoVia,
        numeroVia: existente.numeroVia,
        barrio: existente.barrio,
        ciudad: existente.ciudad,
        telefono: existente.telefono,
        esPrincipal: false, // La versión previa sigue como principal
        registroNumero: existente.registroNumero + 1,
        syncVersion: existente.syncVersion,
        isSynced: true, // Ya existe en la base de datos remota, no sube duplicado
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deviceId: nueva.deviceId,
        encuestadorId: nueva.encuestadorId,
        encuestadorNombre: nueva.encuestadorNombre,
        encuestadorEmail: nueva.encuestadorEmail,
      );

      await savePersona(personaLocal);
      return {'tipo': 'identico', 'persona': personaLocal};
    } else {
      // Caso 2B: Datos MODIFICADOS / CON DISCREPANCIAS
      final personaActualizada = Persona(
        id: nueva.id,
        cedula: existente.cedula,
        nombreCompleto: existente.nombreCompleto,
        fechaNacimiento: existente.fechaNacimiento,
        tipoVia: nueva.tipoVia,
        numeroVia: nueva.numeroVia,
        barrio: nueva.barrio,
        ciudad: nueva.ciudad,
        telefono: nueva.telefono,
        esPrincipal: true,
        registroNumero: existente.registroNumero + 1,
        syncVersion: existente.syncVersion + 1,
        isSynced: isOnline,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deviceId: nueva.deviceId,
        encuestadorId: nueva.encuestadorId,
        encuestadorNombre: nueva.encuestadorNombre,
        encuestadorEmail: nueva.encuestadorEmail,
      );

      await actualizarConHistorial(
        existente: existente,
        nueva: personaActualizada,
      );

      if (isOnline) {
        await sincronizarPersonaManual(personaActualizada);
      }

      // Generar Reporte para el Administrador
      final cambiosTexto = diferencias.entries.map((e) {
        final campoNombre = e.key.replaceAll('_', ' ').toUpperCase();
        return '$campoNombre: "${e.value.$1}" ➔ "${e.value.$2}"';
      }).join(', ');

      await _db.writeTransaction((tx) async {
        await tx.execute(
          '''INSERT INTO reportes_cambios 
             (id, cedula, nombre_persona, encuestador_id, encuestador_nombre, encuestador_anterior_nombre, campos_modificados, fecha, leido_admin, is_deleted)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            _uuid.v4(),
            existente.cedula,
            existente.nombreCompleto,
            nueva.encuestadorId,
            nueva.encuestadorNombre,
            existente.encuestadorNombre.isNotEmpty ? existente.encuestadorNombre : 'Primer encuestador',
            cambiosTexto,
            DateTime.now().toIso8601String(),
            0, // No leído por el admin
            0,
          ],
        );
      });

      return {
        'tipo': 'modificado',
        'persona': personaActualizada,
        'diferencias': diferencias,
      };
    }
  }

  /// Stream de reportes de cambios entre encuestadores
  Stream<List<ReporteCambio>> watchReportesCambios() {
    return _db.watch(
      'SELECT * FROM reportes_cambios WHERE is_deleted = 0 ORDER BY fecha DESC',
    ).map((rows) => rows.map((r) => ReporteCambio.fromMap(r)).toList());
  }

  /// Conteo de reportes no leídos para el badge del admin
  Stream<int> watchConteoReportesNoLeidos() {
    return _db.watch(
      'SELECT COUNT(*) as count FROM reportes_cambios WHERE is_deleted = 0 AND leido_admin = 0',
    ).map((rows) => (rows.isNotEmpty ? rows.first['count'] as int? : 0) ?? 0);
  }

  /// Marcar reporte como leído por el admin
  Future<void> marcarReporteLeido(String id) async {
    await _db.writeTransaction((tx) async {
      await tx.execute(
        'UPDATE reportes_cambios SET leido_admin = 1 WHERE id = ?',
        [id],
      );
    });
  }

  /// Marcar todos los reportes como leídos
  Future<void> marcarTodosReportesLeidos() async {
    await _db.writeTransaction((tx) async {
      await tx.execute('UPDATE reportes_cambios SET leido_admin = 1');
    });
  }

  /// Sincronizar un registro individual manualmente
  Future<bool> sincronizarPersonaManual(Persona persona) async {
    final ok = await _supabaseService.uploadPersona(persona.toMap());
    await _db.writeTransaction((tx) async {
      await tx.execute('UPDATE personas SET is_synced = 1 WHERE id = ?', [persona.id]);
    });
    return ok;
  }

  /// Sincronizar todos los registros offline pendientes manualmente
  Future<int> sincronizarTodosManual({String? encuestadorId}) async {
    final query = encuestadorId != null && encuestadorId.isNotEmpty
        ? 'SELECT * FROM personas WHERE is_deleted = 0 AND is_synced = 0 AND encuestador_id = ?'
        : 'SELECT * FROM personas WHERE is_deleted = 0 AND is_synced = 0';
    final params = encuestadorId != null && encuestadorId.isNotEmpty ? [encuestadorId] : <String>[];

    final offlineRows = await _db.getAll(query, params);
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

  /// Elimina una persona y todas sus versiones de la base de datos (local y remoto)
  Future<void> eliminarPersonaCompleta(String cedula) async {
    await _db.writeTransaction((tx) async {
      await tx.execute('UPDATE personas SET is_deleted = 1 WHERE cedula = ?', [cedula]);
      await tx.execute('DELETE FROM reportes_cambios WHERE cedula = ?', [cedula]);
      await tx.execute('DELETE FROM personas_historial WHERE cedula = ?', [cedula]);
    });
    try {
      await _supabaseService.deletePersonaByCedula(cedula);
    } catch (_) {}
  }

  /// Limpia absolutamente todos los registros de personas para empezar desde cero
  Future<void> limpiarTodosLosRegistros() async {
    await _db.writeTransaction((tx) async {
      await tx.execute('DELETE FROM personas');
      await tx.execute('DELETE FROM personas_historial');
      await tx.execute('DELETE FROM reportes_cambios');
    });
    try {
      await _supabaseService.deleteAllPersonas();
    } catch (_) {}
  }

  /// Estadísticas (filtradas por encuestador o globales si encuestadorId es null)
  Future<Map<String, dynamic>> getEstadisticas({String? encuestadorId}) async {
    final now = DateTime.now();
    final hoyInicio = DateTime(now.year, now.month, now.day).toIso8601String();
    final semanaInicio = now.subtract(const Duration(days: 7)).toIso8601String();
    final mesInicio = DateTime(now.year, now.month, 1).toIso8601String();

    final whereUser = encuestadorId != null && encuestadorId.isNotEmpty ? ' AND encuestador_id = ?' : '';
    final userParams = encuestadorId != null && encuestadorId.isNotEmpty ? [encuestadorId] : <String>[];

    final total = await _db.getOptional(
      'SELECT COUNT(DISTINCT cedula) as count FROM personas WHERE is_deleted = 0$whereUser',
      userParams,
    );
    final hoy = await _db.getOptional(
      'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND es_principal = 1 AND created_at >= ?$whereUser',
      [hoyInicio, ...userParams],
    );
    final semana = await _db.getOptional(
      'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND es_principal = 1 AND created_at >= ?$whereUser',
      [semanaInicio, ...userParams],
    );
    final mes = await _db.getOptional(
      'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND es_principal = 1 AND created_at >= ?$whereUser',
      [mesInicio, ...userParams],
    );
    final conActualizaciones = await _db.getOptional(
      'SELECT COUNT(DISTINCT cedula) as count FROM personas WHERE is_deleted = 0 AND registro_numero > 1$whereUser',
      userParams,
    );
    final pendientesSync = await _db.getOptional(
      'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND is_synced = 0$whereUser',
      userParams,
    );
    final ultimoRegistro = await _db.getOptional(
      'SELECT nombre_completo, cedula, created_at, encuestador_nombre FROM personas WHERE is_deleted = 0$whereUser ORDER BY created_at DESC LIMIT 1',
      userParams,
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
      'ultimo_encuestador': ultimoRegistro?['encuestador_nombre'] ?? '',
    };
  }

  /// Desglose de estadísticas y sincronización por cada encuestador (para panel del Admin)
  Future<List<Map<String, dynamic>>> getEstadisticasPorEncuestador() async {
    // 1. Obtener encuestadores activos
    final encuestadores = await _db.getAll(
      "SELECT id, nombre, email, telefono FROM usuarios WHERE rol = 'encuestador' AND is_deleted = 0 ORDER BY nombre ASC",
    );

    final resultado = <Map<String, dynamic>>[];

    for (final enc in encuestadores) {
      final encId = enc['id'] as String;
      final encNombre = enc['nombre'] as String;
      final encEmail = enc['email'] as String;

      final total = await _db.getOptional(
        'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND es_principal = 1 AND encuestador_id = ?',
        [encId],
      );
      final sincronizados = await _db.getOptional(
        'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND is_synced = 1 AND encuestador_id = ?',
        [encId],
      );
      final pendientes = await _db.getOptional(
        'SELECT COUNT(*) as count FROM personas WHERE is_deleted = 0 AND is_synced = 0 AND encuestador_id = ?',
        [encId],
      );
      final ultimo = await _db.getOptional(
        'SELECT created_at FROM personas WHERE is_deleted = 0 AND encuestador_id = ? ORDER BY created_at DESC LIMIT 1',
        [encId],
      );

      resultado.add({
        'id': encId,
        'nombre': encNombre,
        'email': encEmail,
        'telefono': enc['telefono'] ?? '',
        'total': total?['count'] ?? 0,
        'sincronizados': sincronizados?['count'] ?? 0,
        'pendientes': pendientes?['count'] ?? 0,
        'ultima_actividad': ultimo?['created_at'] ?? '',
      });
    }

    return resultado;
  }
}
