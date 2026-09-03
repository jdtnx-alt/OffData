import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/usuario.dart';
import '../../repositories/usuario_repository.dart';

class MobileEncuestadoresView extends StatefulWidget {
  const MobileEncuestadoresView({super.key});

  @override
  State<MobileEncuestadoresView> createState() => _MobileEncuestadoresViewState();
}

class _MobileEncuestadoresViewState extends State<MobileEncuestadoresView> {
  String _searchQuery = '';

  void _mostrarCrearEditarModal(BuildContext context, {Usuario? usuario}) {
    final repo = context.read<UsuarioRepository>();
    final isEditing = usuario != null;

    final nombreController = TextEditingController(text: usuario?.nombre ?? '');
    final emailController = TextEditingController(text: usuario?.email ?? '');
    final telefonoController = TextEditingController(text: usuario?.telefono ?? '');
    final passController = TextEditingController(text: usuario?.password ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isEditing ? Icons.edit_outlined : Icons.person_add_outlined, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Text(isEditing ? 'Editar Encuestador' : 'Nuevo Encuestador', style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, size: 18),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Ingresa el nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  enabled: !isEditing, // Email no editable para mantener consistencia
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    helperText: isEditing ? 'El correo no se puede cambiar' : null,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.trim().isEmpty ? 'Ingresa el correo' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono / Celular',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passController,
                  decoration: InputDecoration(
                    labelText: isEditing ? 'Nueva Contraseña' : 'Contraseña de Acceso',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  ),
                  validator: (v) => v!.trim().length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                if (isEditing) {
                  final updated = usuario.copyWith(
                    nombre: nombreController.text.trim(),
                    telefono: telefonoController.text.trim(),
                    password: passController.text.trim(),
                  );
                  await repo.updateUsuario(updated);
                } else {
                  await repo.createEncuestador(
                    nombre: nombreController.text.trim(),
                    email: emailController.text.trim(),
                    telefono: telefonoController.text.trim(),
                    password: passController.text.trim(),
                  );
                }

                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(isEditing
                              ? 'Encuestador actualizado correctamente'
                              : 'Encuestador creado exitosamente'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(isEditing ? 'GUARDAR' : 'CREAR'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, Usuario usuario) {
    final repo = context.read<UsuarioRepository>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 36),
        title: const Text('Eliminar Encuestador', textAlign: TextAlign.center),
        content: Text(
          '¿Estás seguro de que deseas eliminar a "${usuario.nombre}" (${usuario.email})? Ya no podrá acceder a la plataforma.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await repo.deleteUsuario(usuario.id);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Encuestador eliminado correctamente'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<UsuarioRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Encuestadores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Gestión del Equipo de Campo', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      body: StreamBuilder<List<Usuario>>(
        stream: repo.watchEncuestadores(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final todos = snapshot.data ?? [];
          final encuestadores = _searchQuery.isEmpty
              ? todos
              : todos.where((u) {
                  final q = _searchQuery.toLowerCase();
                  return u.nombre.toLowerCase().contains(q) ||
                      u.email.toLowerCase().contains(q) ||
                      u.telefono.toLowerCase().contains(q);
                }).toList();

          return Column(
            children: [
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar encuestador por nombre o correo...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

              // Lista
              Expanded(
                child: encuestadores.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 14),
                            const Text('No hay encuestadores registrados', style: TextStyle(color: Colors.white60)),
                            const SizedBox(height: 6),
                            const Text('Presiona el botón + para registrar uno', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: encuestadores.length,
                        itemBuilder: (context, index) {
                          final enc = encuestadores[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                                    child: Text(
                                      enc.nombre.isNotEmpty ? enc.nombre[0].toUpperCase() : 'E',
                                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                enc.nombre,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'ENCUESTADOR',
                                                style: TextStyle(fontSize: 9, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(enc.email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        if (enc.telefono.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text('Tel: ${enc.telefono}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Acciones
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white60),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _mostrarCrearEditarModal(context, usuario: enc);
                                      } else if (val == 'delete') {
                                        _confirmarEliminar(context, enc);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            SizedBox(width: 8),
                                            Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarCrearEditarModal(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Encuestador'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
