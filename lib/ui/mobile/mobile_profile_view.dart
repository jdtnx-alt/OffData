import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class MobileProfileView extends StatelessWidget {
  const MobileProfileView({super.key});

  void _mostrarCambiarPassword(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final actualController = TextEditingController();
    final nuevaController = TextEditingController();
    final confirmarController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Cambiar Contraseña', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: actualController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña Actual',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                ),
                validator: (v) => v!.isEmpty ? 'Ingresa tu contraseña actual' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nuevaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                ),
                validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmarController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check_circle_outline, size: 18),
                ),
                validator: (v) => v != nuevaController.text ? 'Las contraseñas no coinciden' : null,
              ),
            ],
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
              final ok = await auth.changePassword(actualController.text, nuevaController.text);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(ok
                            ? 'Contraseña actualizada correctamente'
                            : 'La contraseña actual es incorrecta'),
                      ],
                    ),
                    backgroundColor: ok ? Colors.green : Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('ACTUALIZAR'),
          ),
        ],
      ),
    );
  }

  void _mostrarEditarPerfil(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final nombreController = TextEditingController(text: auth.name);
    final telefonoController = TextEditingController(text: auth.phone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Editar Perfil', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined, size: 18),
                ),
                validator: (v) => v!.trim().isEmpty ? 'El nombre es requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined, size: 18),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
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
              await auth.updateProfile(
                newName: nombreController.text,
                newPhone: telefonoController.text,
              );
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Perfil actualizado correctamente'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  void _confirmarLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.logout, color: Colors.redAccent, size: 36),
        title: const Text('Cerrar Sesión', textAlign: TextAlign.center),
        content: const Text(
          '¿Estás seguro de que deseas salir de tu cuenta? Podrás volver a iniciar sesión con tus credenciales.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perfil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Cuenta y Seguridad', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Header de usuario
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                  child: Text(
                    auth.name.isNotEmpty ? auth.name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 36, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.email,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'ADMINISTRADOR',
                    style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Información de Perfil
          _seccion('Información Personal'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _itemInfo(Icons.badge_outlined, 'Nombre', auth.name),
                const Divider(height: 1, indent: 48),
                _itemInfo(Icons.email_outlined, 'Correo', auth.email),
                const Divider(height: 1, indent: 48),
                _itemInfo(Icons.phone_outlined, 'Teléfono', auth.phone),
                const Divider(height: 1, indent: 48),
                _itemInfo(Icons.shield_outlined, 'Modo de Base de Datos', 'Local First & Supabase Sync'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _mostrarEditarPerfil(context),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar Información'),
            ),
          ),
          const SizedBox(height: 16),

          // Seguridad y Cuenta
          _seccion('Seguridad'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.blueAccent),
                  title: const Text('Cambiar Contraseña', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Actualiza la clave de acceso a la app', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  onTap: () => _mostrarCambiarPassword(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón Cerrar Sesión
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                foregroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _confirmarLogout(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('CERRAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _seccion(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.blueAccent.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _itemInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent.withValues(alpha: 0.8)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value.isNotEmpty ? value : '—', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
