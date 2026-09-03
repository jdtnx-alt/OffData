import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/persona.dart';
import '../../models/persona_historial.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/persona_repository.dart';
import 'mobile_persona_form_view.dart';

class MobilePersonaDetailView extends StatefulWidget {
  final Persona persona;
  const MobilePersonaDetailView({super.key, required this.persona});

  @override
  State<MobilePersonaDetailView> createState() => _MobilePersonaDetailViewState();
}

class _MobilePersonaDetailViewState extends State<MobilePersonaDetailView> {
  List<Persona> _versiones = [];
  List<PersonaHistorial> _historial = [];
  List<String> _encuestadores = [];
  bool _loading = true;
  bool _mostrarHistorial = true; // Abierto por defecto para que sea visible de inmediato

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final repo = context.read<PersonaRepository>();
      final versiones = await repo.getAllVersionesByCedula(widget.persona.cedula);
      final historial = await repo.getHistorialByCedula(widget.persona.cedula);
      final encuestadores = await repo.getEncuestadoresPorCedula(widget.persona.cedula);
      if (mounted) {
        setState(() {
          _versiones = versiones;
          _historial = historial;
          _encuestadores = encuestadores;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos en detalle: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final p = widget.persona;
    final tieneMultiples = _versiones.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Registro'),
        actions: [
          IconButton(
            tooltip: 'Editar o Actualizar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MobilePersonaFormView(persona: p)),
              );
              if (result == true && mounted) {
                setState(() => _loading = true);
                await _cargarDatos();
              }
            },
          ),
          if (isAdmin)
            IconButton(
              tooltip: 'Eliminar Registro',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmarEliminar(context, p),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ─── ALERTA DESTACADA DE MÚLTIPLES REGISTROS / DUPLICADOS ─────
                if (tieneMultiples)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Múltiples registros detectados (${_versiones.length} ingresos)',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isAdmin
                              ? 'Esta persona fue registrada ${_versiones.length} veces. Los datos más recientes se muestran como PRINCIPALES y los anteriores se conservan abajo como SECUNDARIOS en el historial.'
                              : 'Esta persona cuenta con ${_versiones.length} versiones registradas. Se muestran los datos más recientes como principales.',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                // ─── AVATAR Y NOMBRE ─────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: tieneMultiples ? Colors.orange.withValues(alpha: 0.15) : Colors.blueAccent.withValues(alpha: 0.15),
                        child: Text(
                          p.nombreCompleto.isNotEmpty ? p.nombreCompleto[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 36,
                            color: tieneMultiples ? Colors.orange : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(p.nombreCompleto, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      _statusBadge(p),
                      if (_encuestadores.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _encuestadores.length > 1
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.blueAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _encuestadores.length > 1
                                    ? Colors.orange.withValues(alpha: 0.4)
                                    : Colors.blueAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _encuestadores.length > 1 ? Icons.group_outlined : Icons.person_pin_outlined,
                                  size: 14,
                                  color: _encuestadores.length > 1 ? Colors.orangeAccent : Colors.blueAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _encuestadores.length > 1
                                      ? 'Entrevistada por: ${_encuestadores.join(' y ')}'
                                      : 'Encuestador: ${_encuestadores.first}',
                                  style: TextStyle(
                                    color: _encuestadores.length > 1 ? Colors.orangeAccent : Colors.blueAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── DATOS PRINCIPALES (ÚLTIMOS INGRESADOS) ───────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.greenAccent),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'DATOS PRINCIPALES (Última versión ingresada)',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      if (p.encuestadorNombre.isNotEmpty)
                        Text(
                          'Por: ${p.encuestadorNombre}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                    ],
                  ),
                ),

                _seccion('Información Principal'),
                _datoCard([
                  _dato('Cédula', p.cedula, Icons.badge_outlined),
                  _dato('Fecha de Nacimiento', _formatFecha(p.fechaNacimiento), Icons.cake_outlined),
                  if (p.telefono.isNotEmpty)
                    _dato('Celular', p.telefono, Icons.phone_outlined),
                ]),
                const SizedBox(height: 16),
                _seccion('Dirección'),
                _datoCard([
                  if (p.tipoVia.isNotEmpty && p.numeroVia.isNotEmpty)
                    _dato('Vía', '${p.tipoVia} ${p.numeroVia}', Icons.signpost_outlined),
                  if (p.barrio.isNotEmpty)
                    _dato('Barrio', p.barrio, Icons.location_city_outlined),
                  if (p.ciudad.isNotEmpty)
                    _dato('Ciudad', p.ciudad, Icons.map_outlined),
                ]),

                if (p.encuestadorNombre.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _seccion('Registrado por'),
                  _datoCard([
                    _dato('Encuestador', p.encuestadorNombre, Icons.person_pin_outlined),
                    if (p.encuestadorEmail.isNotEmpty)
                      _dato('Correo Encuestador', p.encuestadorEmail, Icons.email_outlined),
                  ]),
                ],

                // ─── REGISTROS SECUNDARIOS / ANTERIORES ───────────────
                if (tieneMultiples) ...[
                  const SizedBox(height: 28),
                  InkWell(
                    onTap: () => setState(() => _mostrarHistorial = !_mostrarHistorial),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history, color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_versiones.length - 1} registro${_versiones.length > 2 ? 's' : ''} anterior${_versiones.length > 2 ? 'es' : ''} (Datos Secundarios)',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          Icon(
                            _mostrarHistorial ? Icons.expand_less : Icons.expand_more,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_mostrarHistorial) ...[
                    const SizedBox(height: 12),
                    if (_historial.isNotEmpty) ...[
                      _seccion('Comparativa de Cambios Registrados'),
                      ..._historial.map((h) => _cambioCard(h)),
                      const SizedBox(height: 12),
                    ],
                    _seccion('Detalle de Registros Secundarios Anteriores'),
                    ..._versiones
                        .where((v) => !v.esPrincipal)
                        .map((v) => _versionCard(v)),
                  ],
                ],

                const SizedBox(height: 20),
                // Metadata
                Text(
                  'Registro #${p.registroNumero} • Creado: ${_formatFechaHora(p.createdAt)}\n'
                  'Última actualización: ${_formatFechaHora(p.updatedAt)}',
                  style: const TextStyle(color: Colors.white30, fontSize: 10, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _seccion(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.8),
      ),
    );
  }

  Widget _datoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 48, color: Colors.white.withValues(alpha: 0.06)),
          ],
        ],
      ),
    );
  }

  Widget _dato(String label, String value, IconData icon) {
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
                Text(value.isNotEmpty ? value : '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(Persona p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: p.isSynced ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: p.isSynced ? Colors.green.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                p.isSynced ? Icons.cloud_done : Icons.cloud_off,
                size: 13,
                color: p.isSynced ? Colors.greenAccent : Colors.orangeAccent,
              ),
              const SizedBox(width: 6),
              Text(
                p.isSynced ? 'Sincronizado' : 'Pendiente Sync Offline',
                style: TextStyle(
                  color: p.isSynced ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cambioCard(PersonaHistorial h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(h.campoLegible, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text(_formatFechaHora(h.fecha), style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Antes: ${h.valorAnterior.isNotEmpty ? h.valorAnterior : "(vacío)"}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, decoration: TextDecoration.lineThrough),
                ),
              ),
              const Icon(Icons.arrow_forward, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ahora: ${h.valorNuevo}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (h.encuestadorNombre.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Modificado por: ${h.encuestadorNombre}',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _versionCard(Persona v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Registro Secundario #${v.registroNumero}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatFechaHora(v.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Dirección: ${v.direccionCompleta}', style: const TextStyle(fontSize: 12)),
            if (v.telefono.isNotEmpty)
              Text('Teléfono: ${v.telefono}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            if (v.encuestadorNombre.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ingresado por encuestador: ${v.encuestadorNombre}',
                  style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(String f) {
    final d = DateTime.tryParse(f);
    if (d == null) return f;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatFechaHora(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _confirmarEliminar(BuildContext context, Persona p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Eliminar Registro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${p.nombreCompleto} (CC ${p.cedula})?\n\nEsta acción eliminará todas las versiones e historial de la plataforma.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<PersonaRepository>().eliminarPersonaCompleta(p.cedula);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Registro de ${p.nombreCompleto} eliminado'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('ELIMINAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
