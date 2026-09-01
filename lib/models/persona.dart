class Persona {
  final String id;
  final String cedula;
  final String nombreCompleto;
  final String fechaNacimiento;
  final String tipoVia;
  final String numeroVia;
  final String barrio;
  final String ciudad;
  final String telefono;
  final bool esPrincipal;
  final int registroNumero;
  final int syncVersion;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String deviceId;
  final bool isDeleted;

  Persona({
    required this.id,
    required this.cedula,
    required this.nombreCompleto,
    required this.fechaNacimiento,
    this.tipoVia = 'Calle',
    this.numeroVia = '',
    this.barrio = '',
    required this.ciudad,
    this.telefono = '',
    this.esPrincipal = true,
    this.registroNumero = 1,
    this.syncVersion = 1,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
    this.isDeleted = false,
  });

  /// Dirección completa formateada para mostrar
  String get direccionCompleta {
    final parts = <String>[];
    if (tipoVia.isNotEmpty && numeroVia.isNotEmpty) {
      parts.add('$tipoVia $numeroVia');
    }
    if (barrio.isNotEmpty) parts.add('Barrio $barrio');
    if (ciudad.isNotEmpty) parts.add(ciudad);
    return parts.join(', ');
  }

  factory Persona.fromMap(Map<String, dynamic> map) {
    return Persona(
      id: map['id'] ?? '',
      cedula: map['cedula'] ?? '',
      nombreCompleto: map['nombre_completo'] ?? '',
      fechaNacimiento: map['fecha_nacimiento'] ?? '',
      tipoVia: map['tipo_via'] ?? 'Calle',
      numeroVia: map['numero_via'] ?? '',
      barrio: map['barrio'] ?? '',
      ciudad: map['ciudad'] ?? '',
      telefono: map['telefono'] ?? '',
      esPrincipal: (map['es_principal'] ?? 1) == 1,
      registroNumero: map['registro_numero'] ?? 1,
      syncVersion: map['sync_version'] ?? 1,
      isSynced: (map['is_synced'] ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      deviceId: map['device_id'] ?? '',
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cedula': cedula,
      'nombre_completo': nombreCompleto,
      'fecha_nacimiento': fechaNacimiento,
      'tipo_via': tipoVia,
      'numero_via': numeroVia,
      'barrio': barrio,
      'ciudad': ciudad,
      'telefono': telefono,
      'es_principal': esPrincipal ? 1 : 0,
      'registro_numero': registroNumero,
      'sync_version': syncVersion,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Persona copyWith({
    String? tipoVia,
    String? numeroVia,
    String? barrio,
    String? ciudad,
    String? telefono,
    bool? esPrincipal,
    int? registroNumero,
    int? syncVersion,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return Persona(
      id: id,
      cedula: cedula,
      nombreCompleto: nombreCompleto,  // inmutable
      fechaNacimiento: fechaNacimiento, // inmutable
      tipoVia: tipoVia ?? this.tipoVia,
      numeroVia: numeroVia ?? this.numeroVia,
      barrio: barrio ?? this.barrio,
      ciudad: ciudad ?? this.ciudad,
      telefono: telefono ?? this.telefono,
      esPrincipal: esPrincipal ?? this.esPrincipal,
      registroNumero: registroNumero ?? this.registroNumero,
      syncVersion: syncVersion ?? this.syncVersion,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deviceId: deviceId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
