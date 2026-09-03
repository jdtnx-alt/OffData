import 'package:powersync/powersync.dart';

const Schema schema = Schema([
  Table('usuarios', [
    Column.text('email'),
    Column.text('password'),
    Column.text('nombre'),
    Column.text('telefono'),
    Column.text('rol'), // 'admin' | 'encuestador'
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.integer('is_deleted'),
  ], indexes: [
    Index('email_idx', [IndexedColumn('email')]),
    Index('rol_idx', [IndexedColumn('rol')]),
  ]),
  Table('personas', [
    Column.text('cedula'),
    Column.text('nombre_completo'),
    Column.text('fecha_nacimiento'),
    Column.text('tipo_via'), // Calle, Carrera, Avenida, etc.
    Column.text('numero_via'), // 15 #30-20
    Column.text('barrio'),
    Column.text('ciudad'),
    Column.text('telefono'), // celular colombiano 10 dígitos
    Column.integer('es_principal'), // 0 o 1
    Column.integer('registro_numero'), // 1,2,3... cuantas veces registrado
    Column.integer('sync_version'),
    Column.integer('is_synced'), // 0 = pendiente offline, 1 = sincronizado
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('device_id'),
    Column.integer('is_deleted'),
    Column.text('encuestador_id'),
    Column.text('encuestador_nombre'),
    Column.text('encuestador_email'),
  ], indexes: [
    Index('cedula_idx', [IndexedColumn('cedula')]),
    Index('cedula_principal_idx', [IndexedColumn('cedula'), IndexedColumn('es_principal')]),
    Index('synced_idx', [IndexedColumn('is_synced')]),
    Index('encuestador_idx', [IndexedColumn('encuestador_id')]),
  ]),
  Table('contactos', [
    Column.text('persona_id'),
    Column.text('tipo'),
    Column.text('valor'),
    Column.text('created_at'),
    Column.integer('is_deleted'),
  ]),
  Table('dispositivos', [
    Column.text('nombre'),
    Column.text('tipo'),
    Column.text('os_version'),
    Column.text('last_sync'),
  ]),
  Table('personas_historial', [
    Column.text('persona_id'), // ID del nuevo registro
    Column.text('cedula'), // para agrupar fácilmente
    Column.text('campo'),
    Column.text('valor_anterior'),
    Column.text('valor_nuevo'),
    Column.text('fecha'),
    Column.text('encuestador_id'),
    Column.text('encuestador_nombre'),
  ]),
  Table('reportes_cambios', [
    Column.text('cedula'),
    Column.text('nombre_persona'),
    Column.text('encuestador_id'),
    Column.text('encuestador_nombre'),
    Column.text('encuestador_anterior_nombre'),
    Column.text('campos_modificados'),
    Column.text('fecha'),
    Column.integer('leido_admin'), // 0 = no leído, 1 = leído
    Column.integer('is_deleted'),
  ], indexes: [
    Index('reportes_cedula_idx', [IndexedColumn('cedula')]),
    Index('reportes_leido_idx', [IndexedColumn('leido_admin')]),
  ]),
]);

