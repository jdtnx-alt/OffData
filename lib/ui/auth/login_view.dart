import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: AuthProvider.defaultEmail);
  final _passwordController = TextEditingController(text: AuthProvider.defaultPassword);
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.login(_emailController.text, _passwordController.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!success) {
      setState(() {
        _errorMessage = 'Correo o contraseña incorrectos. Verifica tus credenciales o el estado de tu cuenta.';
      });
    }
  }

  void _seleccionarCredenciales({required String email, required String pass}) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = pass;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Ícono
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4), width: 2),
                    ),
                    child: const Icon(Icons.cloud_sync_outlined, size: 44, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'OffData',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sistema de Registro & Sincronización Offline',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Campo Correo
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.trim().isEmpty ? 'Ingresa tu correo' : null,
                  ),
                  const SizedBox(height: 14),

                  // Campo Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                          color: Colors.white60,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Ingresa tu contraseña' : null,
                  ),
                  const SizedBox(height: 22),

                  // Botón Iniciar Sesión
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'INICIAR SESIÓN',
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 15),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Acceso Rápido por Roles
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Acceso rápido con cuentas de prueba:',
                      style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.admin_panel_settings, size: 14, color: Colors.amber),
                        label: const Text('Admin', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.amber.withValues(alpha: 0.12),
                        side: BorderSide(color: Colors.amber.withValues(alpha: 0.35)),
                        onPressed: () => _seleccionarCredenciales(
                          email: AuthProvider.defaultEmail,
                          pass: AuthProvider.defaultPassword,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.badge_outlined, size: 14, color: Colors.blueAccent),
                        label: const Text('Encuestador 1', style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.12),
                        side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.35)),
                        onPressed: () => _seleccionarCredenciales(
                          email: AuthProvider.encuestador1Email,
                          pass: AuthProvider.encuestador1Password,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.badge_outlined, size: 14, color: Colors.greenAccent),
                        label: const Text('Encuestador 2', style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.greenAccent.withValues(alpha: 0.12),
                        side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.35)),
                        onPressed: () => _seleccionarCredenciales(
                          email: AuthProvider.encuestador2Email,
                          pass: AuthProvider.encuestador2Password,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Admin: admin@offdata.com (OffData2026*)', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        SizedBox(height: 2),
                        Text('• Encuestador 1: encuestador1@offdata.com (Encuestador2026*)', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        SizedBox(height: 2),
                        Text('• Encuestador 2: encuestador2@offdata.com (Encuestador2026*)', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
