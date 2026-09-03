import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reporte_cambio.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/persona_repository.dart';
import '../widgets/network_badge.dart';

class MobileStatsView extends StatefulWidget {
  final bool isOnline;
  const MobileStatsView({super.key, required this.isOnline});

  @override
  State<MobileStatsView> createState() => _MobileStatsViewState();
}

class _MobileStatsViewState extends State<MobileStatsView> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _statsEncuestadores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarStats();
  }

  Future<void> _cargarStats() async {
    final auth = context.read<AuthProvider>();
    final repo = context.read<PersonaRepository>();

    final encId = auth.isAdmin ? null : auth.userId;
    final stats = await repo.getEstadisticas(encuestadorId: encId);

    List<Map<String, dynamic>> encuestadoresStats = [];
    if (auth.isAdmin) {
      encuestadoresStats = await repo.getEstadisticasPorEncuestador();
    }

    if (mounted) {
      setState(() {
        _stats = stats;
        _statsEncuestadores = encuestadoresStats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final repo = context.watch<PersonaRepository>();
    final isAdmin = auth.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'Estadísticas Globales' : 'Mis Métricas',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              isAdmin ? 'Métricas de la Plataforma & Sync' : 'Rendimiento: ${auth.name}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          const NetworkBadge(),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Actualizar métricas',
            onPressed: () {
              setState(() => _loading = true);
              _cargarStats();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Aviso offline
                  if (!widget.isOnline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_off, color: Colors.orange, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sin conexión — mostrando datos locales. Las estadísticas se sincronizarán al reconectar.',
                              style: TextStyle(color: Colors.orange, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tarjeta principal — TOTAL
                  _statCardGrande(
                    icon: Icons.people,
                    label: isAdmin ? 'Total Personas Registradas en Plataforma' : 'Personas Registradas por Mí',
                    value: '${_stats!['total']}',
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 14),

                  // Grid de stats
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.35,
                    children: [
                      _statCardChico(
                        icon: Icons.today_outlined,
                        label: 'Registros Hoy',
                        value: '${_stats!['hoy']}',
                        color: Colors.greenAccent,
                      ),
                      _statCardChico(
                        icon: Icons.date_range_outlined,
                        label: 'Esta Semana',
                        value: '${_stats!['semana']}',
                        color: Colors.cyanAccent,
                      ),
                      _statCardChico(
                        icon: Icons.calendar_month_outlined,
                        label: 'Este Mes',
                        value: '${_stats!['mes']}',
                        color: Colors.purpleAccent,
                      ),
                      _statCardChico(
                        icon: Icons.history,
                        label: isAdmin ? 'Con Actualizaciones' : 'Mis Actualizaciones',
                        value: '${_stats!['con_actualizaciones']}',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── ESTADO DE SINCRONIZACIÓN (ADMIN O ENCUESTADOR) ────────
                  _seccion('Estado de Sincronización'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_stats!['pendientes_sync'] ?? 0) > 0
                          ? Colors.amber.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_stats!['pendientes_sync'] ?? 0) > 0
                            ? Colors.amber.withValues(alpha: 0.4)
                            : Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (_stats!['pendientes_sync'] ?? 0) > 0 ? Icons.sync_problem : Icons.cloud_done,
                          color: (_stats!['pendientes_sync'] ?? 0) > 0 ? Colors.amber : Colors.greenAccent,
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_stats!['pendientes_sync']} registros pendientes de sincronización',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_stats!['pendientes_sync'] ?? 0) > 0 ? Colors.amber : Colors.greenAccent,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAdmin
                                    ? 'Total acumulado en el sistema pendiente por subir al servidor central.'
                                    : 'Registros que ingresaste sin internet y están guardados en tu dispositivo.',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── DESGLOSE POR ENCUESTADOR (SOLO ADMIN) ─────────────────
                  if (isAdmin) ...[
                    _seccion('Desglose de Registros & Sync por Encuestador'),
                    if (_statsEncuestadores.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No hay encuestadores activos con registros',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      )
                    else
                      ..._statsEncuestadores.map((enc) {
                        final total = enc['total'] as int;
                        final sinc = enc['sincronizados'] as int;
                        final pend = enc['pendientes'] as int;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                                      child: Text(
                                        (enc['nombre'] as String).isNotEmpty ? (enc['nombre'] as String)[0].toUpperCase() : 'E',
                                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            enc['nombre'] as String,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            enc['email'] as String,
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (pend > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          '$pend pend.',
                                          style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _miniIndicador('Total', '$total', Colors.blueAccent),
                                    const SizedBox(width: 8),
                                    _miniIndicador('Sincronizados', '$sinc', Colors.greenAccent),
                                    const SizedBox(width: 8),
                                    _miniIndicador('Pendientes', '$pend', pend > 0 ? Colors.amber : Colors.white38),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                  ],

                  // Reportes de Actualizaciones entre Encuestadores (Solo Admin)
                  if (isAdmin) ...[
                    _seccion('Reportes de Modificaciones entre Encuestadores'),
                    StreamBuilder<List<ReporteCambio>>(
                      stream: repo.watchReportesCambios(),
                      builder: (context, repSnapshot) {
                        final reportes = repSnapshot.data ?? [];
                        if (reportes.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'No se han registrado modificaciones o discrepancias entre encuestadores.',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: reportes.take(5).map((rep) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: rep.leidoAdmin
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.orange.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: rep.leidoAdmin
                                      ? Colors.white10
                                      : Colors.orange.withValues(alpha: 0.4),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.sync_alt,
                                  color: rep.leidoAdmin ? Colors.grey : Colors.orangeAccent,
                                  size: 20,
                                ),
                                title: Text(
                                  '${rep.nombrePersona} (CC ${rep.cedula})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${rep.encuestadorNombre} actualizó datos de ${rep.encuestadorAnteriorNombre}\n${rep.camposModificados}',
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                                trailing: rep.leidoAdmin
                                    ? const Icon(Icons.check, size: 16, color: Colors.white38)
                                    : IconButton(
                                        icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.greenAccent),
                                        tooltip: 'Marcar visto',
                                        onPressed: () => repo.marcarReporteLeido(rep.id),
                                      ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Último registro
                  if (_stats!['ultimo_nombre'] != '-') ...[
                    _seccion(isAdmin ? 'Último Registro en la Plataforma' : 'Mi Último Registro'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                            child: Text(
                              (_stats!['ultimo_nombre'] as String)[0].toUpperCase(),
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_stats!['ultimo_nombre'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text('CC ${_stats!['ultimo_cedula']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                if (isAdmin && (_stats!['ultimo_encuestador'] as String).isNotEmpty)
                                  Text(
                                    'Encuestador: ${_stats!['ultimo_encuestador']}',
                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10),
                                  ),
                                if ((_stats!['ultimo_fecha'] as String).isNotEmpty)
                                  Text(
                                    _formatFechaHora(DateTime.tryParse(_stats!['ultimo_fecha']) ?? DateTime.now()),
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.access_time, color: Colors.white24, size: 16),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _miniIndicador(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.blueAccent.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _statCardGrande({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color)),
                ),
                Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCardChico({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatFechaHora(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
