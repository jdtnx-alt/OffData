import 'package:flutter_test/flutter_test.dart';
import 'package:offdata/models/usuario.dart';
import 'package:offdata/models/persona.dart';
import 'package:offdata/models/persona_historial.dart';
import 'package:offdata/models/reporte_cambio.dart';

void main() {
  group('Usuario Model Tests', () {
    test('Admin role verification and serialization', () {
      final admin = Usuario(
        id: 'user-admin-001',
        email: 'admin@offdata.com',
        password: 'OffData2026*',
        nombre: 'Administrador Principal',
        telefono: '300 123 4567',
        rol: 'admin',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isEncuestador, isFalse);

      final map = admin.toMap();
      final fromMap = Usuario.fromMap(map);

      expect(fromMap.id, admin.id);
      expect(fromMap.email, admin.email);
      expect(fromMap.rol, 'admin');
      expect(fromMap.isAdmin, isTrue);
    });

    test('Encuestador role verification and copyWith', () {
      final enc = Usuario(
        id: 'user-enc-001',
        email: 'encuestador1@offdata.com',
        password: 'Encuestador2026*',
        nombre: 'Carlos Mendoza',
        telefono: '310 987 6543',
        rol: 'encuestador',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(enc.isAdmin, isFalse);
      expect(enc.isEncuestador, isTrue);

      final edited = enc.copyWith(nombre: 'Carlos Mendoza Editado', telefono: '300 000 0000');
      expect(edited.nombre, 'Carlos Mendoza Editado');
      expect(edited.telefono, '300 000 0000');
      expect(edited.id, enc.id);
      expect(edited.rol, 'encuestador');
    });
  });

  group('Persona Model & Duplicates/Authorship Tests', () {
    test('Persona includes encuestador authorship and versioning', () {
      final personaV1 = Persona(
        id: 'p-001',
        cedula: '1020304050',
        nombreCompleto: 'Juan Pérez',
        fechaNacimiento: '1995-05-15',
        tipoVia: 'Calle',
        numeroVia: '10 #20-30',
        barrio: 'Laureles',
        ciudad: 'Medellín',
        telefono: '3001112233',
        esPrincipal: false, // Secondary old version
        registroNumero: 1,
        syncVersion: 1,
        isSynced: true,
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
        deviceId: 'dev-1',
        encuestadorId: 'user-enc-001',
        encuestadorNombre: 'Carlos Mendoza',
        encuestadorEmail: 'encuestador1@offdata.com',
      );

      expect(personaV1.esPrincipal, isFalse);
      expect(personaV1.registroNumero, 1);
      expect(personaV1.encuestadorNombre, 'Carlos Mendoza');

      final map = personaV1.toMap();
      final fromMap = Persona.fromMap(map);

      expect(fromMap.cedula, '1020304050');
      expect(fromMap.encuestadorId, 'user-enc-001');
      expect(fromMap.encuestadorNombre, 'Carlos Mendoza');

      // V2 updated by another encuestador
      final personaV2 = Persona(
        id: 'p-002',
        cedula: '1020304050',
        nombreCompleto: 'Juan Pérez',
        fechaNacimiento: '1995-05-15',
        tipoVia: 'Carrera',
        numeroVia: '45 #80-12',
        barrio: 'Poblado',
        ciudad: 'Medellín',
        telefono: '3109998877',
        esPrincipal: true, // Main latest version
        registroNumero: 2,
        syncVersion: 2,
        isSynced: false,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
        deviceId: 'dev-2',
        encuestadorId: 'user-enc-002',
        encuestadorNombre: 'Ana Gómez',
        encuestadorEmail: 'encuestador2@offdata.com',
      );

      expect(personaV2.esPrincipal, isTrue);
      expect(personaV2.registroNumero, 2);
      expect(personaV2.encuestadorNombre, 'Ana Gómez');
    });
  });

  group('PersonaHistorial Model Tests', () {
    test('Historial serialization and field translation', () {
      final hist = PersonaHistorial(
        id: 'h-001',
        personaId: 'p-002',
        cedula: '1020304050',
        campo: 'barrio',
        valorAnterior: 'Laureles',
        valorNuevo: 'Poblado',
        fecha: DateTime(2026, 2, 1),
        encuestadorId: 'user-enc-002',
        encuestadorNombre: 'Ana Gómez',
      );

      expect(hist.campoLegible, 'Barrio');
      expect(hist.encuestadorNombre, 'Ana Gómez');

      final map = hist.toMap();
      final fromMap = PersonaHistorial.fromMap(map);

      expect(fromMap.campo, 'barrio');
      expect(fromMap.valorAnterior, 'Laureles');
      expect(fromMap.valorNuevo, 'Poblado');
      expect(fromMap.encuestadorNombre, 'Ana Gómez');
    });
  });

  group('ReporteCambio Model Tests', () {
    test('ReporteCambio serialization and mapping', () {
      final reporte = ReporteCambio(
        id: 'rep-001',
        cedula: '1020304050',
        nombrePersona: 'Juan Pérez',
        encuestadorId: 'user-enc-002',
        encuestadorNombre: 'Ana Gómez',
        encuestadorAnteriorNombre: 'Carlos Mendoza',
        camposModificados: 'BARRIO: "Laureles" ➔ "Poblado", TELÉFONO: "3001112233" ➔ "3109998877"',
        fecha: DateTime(2026, 2, 1, 10, 30),
        leidoAdmin: false,
      );

      expect(reporte.leidoAdmin, isFalse);
      expect(reporte.encuestadorNombre, 'Ana Gómez');
      expect(reporte.encuestadorAnteriorNombre, 'Carlos Mendoza');

      final map = reporte.toMap();
      final fromMap = ReporteCambio.fromMap(map);

      expect(fromMap.id, 'rep-001');
      expect(fromMap.cedula, '1020304050');
      expect(fromMap.nombrePersona, 'Juan Pérez');
      expect(fromMap.camposModificados, contains('Poblado'));
      expect(fromMap.leidoAdmin, isFalse);
    });
  });
}
