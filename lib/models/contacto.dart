class Contacto {
  final String id;
  final String personaId;
  final String tipo;
  final String valor;
  final DateTime createdAt;
  final bool isDeleted;

  Contacto({
    required this.id,
    required this.personaId,
    required this.tipo,
    required this.valor,
    required this.createdAt,
    this.isDeleted = false,
  });

  factory Contacto.fromMap(Map<String, dynamic> map) {
    return Contacto(
      id: map['id'],
      personaId: map['persona_id'],
      tipo: map['tipo'],
      valor: map['valor'],
      createdAt: DateTime.parse(map['created_at']),
      isDeleted: map['is_deleted'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'persona_id': personaId,
      'tipo': tipo,
      'valor': valor,
      'created_at': createdAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}
