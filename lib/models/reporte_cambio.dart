class ReporteCambio {
  final String id;
  final String cedula;
  final String nombrePersona;
  final String encuestadorId;
  final String encuestadorNombre;
  final String encuestadorAnteriorNombre;
  final String camposModificados;
  final DateTime fecha;
  final bool leidoAdmin;

  ReporteCambio({
    required this.id,
    required this.cedula,
    required this.nombrePersona,
    required this.encuestadorId,
    required this.encuestadorNombre,
    required this.encuestadorAnteriorNombre,
    required this.camposModificados,
    required this.fecha,
    this.leidoAdmin = false,
  });

  factory ReporteCambio.fromMap(Map<String, dynamic> map) {
    return ReporteCambio(
      id: map['id'] ?? '',
      cedula: map['cedula'] ?? '',
      nombrePersona: map['nombre_persona'] ?? '',
      encuestadorId: map['encuestador_id'] ?? '',
      encuestadorNombre: map['encuestador_nombre'] ?? '',
      encuestadorAnteriorNombre: map['encuestador_anterior_nombre'] ?? '',
      camposModificados: map['campos_modificados'] ?? '',
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      leidoAdmin: (map['leido_admin'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cedula': cedula,
      'nombre_persona': nombrePersona,
      'encuestador_id': encuestadorId,
      'encuestador_nombre': encuestadorNombre,
      'encuestador_anterior_nombre': encuestadorAnteriorNombre,
      'campos_modificados': camposModificados,
      'fecha': fecha.toIso8601String(),
      'leido_admin': leidoAdmin ? 1 : 0,
      'is_deleted': 0,
    };
  }
}
