class PersonaHistorial {
  final String id;
  final String personaId;
  final String cedula;
  final String campo;
  final String valorAnterior;
  final String valorNuevo;
  final DateTime fecha;

  PersonaHistorial({
    required this.id,
    required this.personaId,
    required this.cedula,
    required this.campo,
    required this.valorAnterior,
    required this.valorNuevo,
    required this.fecha,
  });

  factory PersonaHistorial.fromMap(Map<String, dynamic> map) {
    return PersonaHistorial(
      id: map['id'] ?? '',
      personaId: map['persona_id'] ?? '',
      cedula: map['cedula'] ?? '',
      campo: map['campo'] ?? '',
      valorAnterior: map['valor_anterior'] ?? '',
      valorNuevo: map['valor_nuevo'] ?? '',
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'persona_id': personaId,
      'cedula': cedula,
      'campo': campo,
      'valor_anterior': valorAnterior,
      'valor_nuevo': valorNuevo,
      'fecha': fecha.toIso8601String(),
    };
  }

  String get campoLegible {
    const labels = {
      'tipo_via': 'Tipo de Vía',
      'numero_via': 'Número de Vía',
      'barrio': 'Barrio',
      'ciudad': 'Ciudad',
      'telefono': 'Teléfono',
    };
    return labels[campo] ?? campo;
  }
}
