class Usuario {
  final String id;
  final String email;
  final String password;
  final String nombre;
  final String telefono;
  final String rol; // 'admin' | 'encuestador'
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Usuario({
    required this.id,
    required this.email,
    required this.password,
    required this.nombre,
    this.telefono = '',
    required this.rol,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  bool get isAdmin => rol.toLowerCase() == 'admin';
  bool get isEncuestador => rol.toLowerCase() == 'encuestador';

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'] ?? '',
      rol: map['rol'] ?? 'encuestador',
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'nombre': nombre,
      'telefono': telefono,
      'rol': rol,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Usuario copyWith({
    String? email,
    String? password,
    String? nombre,
    String? telefono,
    String? rol,
    bool? isActive,
    bool? isDeleted,
  }) {
    return Usuario(
      id: id,
      email: email ?? this.email,
      password: password ?? this.password,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
