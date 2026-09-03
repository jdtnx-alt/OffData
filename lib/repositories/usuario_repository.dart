import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/usuario.dart';

class UsuarioRepository {
  final PowerSyncDatabase _db = AppDatabase().db;
  final _uuid = const Uuid();

  static const String adminEmail = 'admin@offdata.com';
  static const String adminPassword = 'OffData2026*';

  static const String encuestador1Email = 'encuestador1@offdata.com';
  static const String encuestador1Password = 'Encuestador2026*';

  static const String encuestador2Email = 'encuestador2@offdata.com';
  static const String encuestador2Password = 'Encuestador2026*';

  /// Inicializa los usuarios predeterminados si aún no existen
  Future<void> inicializarUsuariosPorDefecto() async {
    try {
      final existentes = await _db.getAll('SELECT * FROM usuarios WHERE is_deleted = 0');
      if (existentes.isEmpty) {
        final now = DateTime.now();

        // 1. Admin
        final admin = Usuario(
          id: 'user-admin-001',
          email: adminEmail,
          password: adminPassword,
          nombre: 'Administrador Principal',
          telefono: '300 123 4567',
          rol: 'admin',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        // 2. Encuestador 1
        final enc1 = Usuario(
          id: 'user-encuestador-001',
          email: encuestador1Email,
          password: encuestador1Password,
          nombre: 'Carlos Mendoza (Encuestador 1)',
          telefono: '310 987 6543',
          rol: 'encuestador',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        // 3. Encuestador 2
        final enc2 = Usuario(
          id: 'user-encuestador-002',
          email: encuestador2Email,
          password: encuestador2Password,
          nombre: 'Ana Gómez (Encuestador 2)',
          telefono: '320 555 1234',
          rol: 'encuestador',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        await _db.writeTransaction((tx) async {
          for (final u in [admin, enc1, enc2]) {
            await tx.execute(
              '''INSERT OR REPLACE INTO usuarios 
                 (id, email, password, nombre, telefono, rol, is_active, created_at, updated_at, is_deleted)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
              [
                u.id,
                u.email.toLowerCase().trim(),
                u.password.trim(),
                u.nombre,
                u.telefono,
                u.rol,
                u.isActive ? 1 : 0,
                u.createdAt.toIso8601String(),
                u.updatedAt.toIso8601String(),
                0,
              ],
            );
          }
        });
        debugPrint('Usuarios predeterminados creados exitosamente');
      }
    } catch (e) {
      debugPrint('Error inicializando usuarios: $e');
    }
  }

  /// Escucha en tiempo real la lista de encuestadores (para el panel admin)
  Stream<List<Usuario>> watchEncuestadores() {
    return _db.watch(
      "SELECT * FROM usuarios WHERE rol = 'encuestador' AND is_deleted = 0 ORDER BY nombre ASC",
    ).map((rows) => rows.map((r) => Usuario.fromMap(r)).toList());
  }

  /// Obtiene todos los usuarios
  Future<List<Usuario>> getUsuarios() async {
    final rows = await _db.getAll('SELECT * FROM usuarios WHERE is_deleted = 0 ORDER BY nombre ASC');
    return rows.map((r) => Usuario.fromMap(r)).toList();
  }

  /// Obtiene todos los encuestadores
  Future<List<Usuario>> getEncuestadores() async {
    final rows = await _db.getAll(
      "SELECT * FROM usuarios WHERE rol = 'encuestador' AND is_deleted = 0 ORDER BY nombre ASC",
    );
    return rows.map((r) => Usuario.fromMap(r)).toList();
  }

  /// Obtiene un usuario por su email
  Future<Usuario?> getUsuarioByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final row = await _db.getOptional(
      'SELECT * FROM usuarios WHERE LOWER(email) = ? AND is_deleted = 0 LIMIT 1',
      [cleanEmail],
    );
    if (row != null) {
      return Usuario.fromMap(row);
    }
    return null;
  }

  /// Obtiene un usuario por su ID
  Future<Usuario?> getUsuarioById(String id) async {
    final row = await _db.getOptional(
      'SELECT * FROM usuarios WHERE id = ? AND is_deleted = 0 LIMIT 1',
      [id],
    );
    return row != null ? Usuario.fromMap(row) : null;
  }

  /// Autentica credenciales
  Future<Usuario?> autenticar(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    // Primero comprobamos en la base de datos local
    final usuario = await getUsuarioByEmail(cleanEmail);
    if (usuario != null && usuario.password == cleanPass && usuario.isActive) {
      return usuario;
    }

    // Fallback con credenciales predeterminadas si la BD aún no ha corrido
    if (cleanEmail == adminEmail.toLowerCase() && cleanPass == adminPassword) {
      return Usuario(
        id: 'user-admin-001',
        email: adminEmail,
        password: adminPassword,
        nombre: 'Administrador Principal',
        telefono: '300 123 4567',
        rol: 'admin',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    if (cleanEmail == encuestador1Email.toLowerCase() && cleanPass == encuestador1Password) {
      return Usuario(
        id: 'user-encuestador-001',
        email: encuestador1Email,
        password: encuestador1Password,
        nombre: 'Carlos Mendoza (Encuestador 1)',
        telefono: '310 987 6543',
        rol: 'encuestador',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    if (cleanEmail == encuestador2Email.toLowerCase() && cleanPass == encuestador2Password) {
      return Usuario(
        id: 'user-encuestador-002',
        email: encuestador2Email,
        password: encuestador2Password,
        nombre: 'Ana Gómez (Encuestador 2)',
        telefono: '320 555 1234',
        rol: 'encuestador',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }

  /// Crear nuevo encuestador
  Future<Usuario> createEncuestador({
    required String email,
    required String password,
    required String nombre,
    String telefono = '',
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final existing = await getUsuarioByEmail(cleanEmail);
    if (existing != null) {
      throw Exception('Ya existe un usuario con el correo $cleanEmail');
    }

    final nuevo = Usuario(
      id: _uuid.v4(),
      email: cleanEmail,
      password: password.trim(),
      nombre: nombre.trim(),
      telefono: telefono.trim(),
      rol: 'encuestador',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _db.writeTransaction((tx) async {
      await tx.execute(
        '''INSERT INTO usuarios 
           (id, email, password, nombre, telefono, rol, is_active, created_at, updated_at, is_deleted)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          nuevo.id,
          nuevo.email,
          nuevo.password,
          nuevo.nombre,
          nuevo.telefono,
          nuevo.rol,
          nuevo.isActive ? 1 : 0,
          nuevo.createdAt.toIso8601String(),
          nuevo.updatedAt.toIso8601String(),
          0,
        ],
      );
    });

    return nuevo;
  }

  /// Actualizar datos de encuestador
  Future<void> updateUsuario(Usuario usuario) async {
    await _db.writeTransaction((tx) async {
      await tx.execute(
        '''UPDATE usuarios 
           SET email = ?, password = ?, nombre = ?, telefono = ?, is_active = ?, updated_at = ?
           WHERE id = ?''',
        [
          usuario.email.trim().toLowerCase(),
          usuario.password.trim(),
          usuario.nombre.trim(),
          usuario.telefono.trim(),
          usuario.isActive ? 1 : 0,
          DateTime.now().toIso8601String(),
          usuario.id,
        ],
      );
    });
  }

  /// Eliminar encuestador (soft delete)
  Future<void> deleteUsuario(String id) async {
    await _db.writeTransaction((tx) async {
      await tx.execute(
        'UPDATE usuarios SET is_deleted = 1, updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );
    });
  }
}
