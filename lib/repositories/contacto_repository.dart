import 'package:powersync/powersync.dart';
import '../database/app_database.dart';
import '../models/contacto.dart';

class ContactoRepository {
  final PowerSyncDatabase _db = AppDatabase().db;

  Stream<List<Contacto>> watchContactosForPersona(String personaId) {
    return _db.watch('SELECT * FROM contactos WHERE persona_id = ? AND is_deleted = 0', parameters: [personaId]).map((rows) {
      return rows.map((row) => Contacto.fromMap(row)).toList();
    });
  }

  Future<void> saveContacto(Contacto contacto) async {
    await _db.writeTransaction((tx) async {
      await tx.execute(
        '''INSERT OR REPLACE INTO contactos (id, persona_id, tipo, valor, created_at, is_deleted)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          contacto.id,
          contacto.personaId,
          contacto.tipo,
          contacto.valor,
          contacto.createdAt.toIso8601String(),
          contacto.isDeleted ? 1 : 0,
        ],
      );
    });
  }

  Future<void> deleteContacto(String id) async {
    await _db.writeTransaction((tx) async {
      await tx.execute('UPDATE contactos SET is_deleted = 1 WHERE id = ?', [id]);
    });
  }
}
