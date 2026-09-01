import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/persona.dart';
import '../../models/persona_historial.dart';
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
  bool _loading = true;
  bool _mostrarHistorial = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final repo = context.read<PersonaRepository>();
    final versiones = await repo.getAllVersionesByCedula(widget.persona.cedula);
    final historial = await repo.getHistorialByCedula(widget.persona.cedula);
    if (mounted) {
      setState(() {
        _versiones = versiones;
        _historial = historial;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.persona;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Registro'),
        actions: [
          IconButton(
            tooltip: 'Editar',
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
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ─── AVATAR Y NOMBRE ─────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                        child: Text(
                          p.nombreCompleto.isNotEmpty ? p.nombreCompleto[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 36, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(p.nombreCompleto, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      _statusBadge(p),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── DATOS PRINCIPALES ───────────────────────────────
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

                // ─── REGISTROS ANTERIORES ────────────────────────────
                if (_versiones.length > 1) ...[
                  const SizedBox(height: 24),
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
                              '${_versiones.length - 1} registro${_versiones.length > 2 ? 's' : ''} anterior${_versiones.length > 2 ? 'es' : ''}',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
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
                    // Cambios en historial
                    if (_historial.isNotEmpty) ...[
                      _seccion('Cambios Registrados'),
                      ..._historial.map((h) => _cambioCard(h)),
                      const SizedBox(height: 12),
                    ],
                    // Versiones anteriores
                    _seccion('Registros Anteriores (Datos Secundarios)'),
                    ..._versiones
                        .where((v) => !v.esPrincipal)
                        .map((v) => _versionCard(v)),
                  ],
                ],

                const SizedBox(height: 20),
                // Metadata
                Text(
                  'Registro #${p.registroNumero} — Creado: ${_formatFechaHora(p.createdAt)}\n'
                  'Actualizado: ${_formatFechaHora(p.updatedAt)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _statusBadge(Persona p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 5),
          Text(
            p.registroNumero > 1
                ? 'Registro #${p.registroNumero} (Datos actualizados)'
                : 'Registro único',
            style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.blueAccent.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _datoCard(List<Widget> children) {
    if (children.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Sin datos', style: TextStyle(color: Colors.grey)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }

  Widget _dato(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueAccent.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cambioCard(PersonaHistorial h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, size: 14, color: Colors.orange),
              const SizedBox(width: 6),
              Text(h.campoLegible, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text(_formatFechaHora(h.fecha), style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _valorChip(h.valorAnterior.isEmpty ? '—' : h.valorAnterior, Colors.red),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
              ),
              Expanded(
                child: _valorChip(h.valorNuevo.isEmpty ? '—' : h.valorNuevo, Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valorChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _versionCard(Persona v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Registro #${v.registroNumero}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13)),
              const Spacer(),
              Text(_formatFechaHora(v.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          if (v.tipoVia.isNotEmpty && v.numeroVia.isNotEmpty)
            Text('${v.tipoVia} ${v.numeroVia}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          if (v.barrio.isNotEmpty) Text('Barrio ${v.barrio}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (v.ciudad.isNotEmpty) Text(v.ciudad, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (v.telefono.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(v.telefono, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatFecha(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
  }

  String _formatFechaHora(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
