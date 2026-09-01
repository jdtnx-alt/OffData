import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarStats();
  }

  Future<void> _cargarStats() async {
    final repo = context.read<PersonaRepository>();
    final stats = await repo.getEstadisticas();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estadísticas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Métricas de Registro', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          const NetworkBadge(),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Actualizar métricas',
            onPressed: () { setState(() => _loading = true); _cargarStats(); },
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
                  // Aviso de datos no actualizados si está offline
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
                              'Sin conexión — mostrando datos locales. Las estadísticas globales se actualizarán al reconectar.',
                              style: TextStyle(color: Colors.orange, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tarjeta principal — TOTAL
                  _statCardGrande(
                    icon: Icons.people,
                    label: 'Total de Personas Registradas',
                    value: '${_stats!['total']}',
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 14),

                  // Grid de stats con aspect ratio corregido para evitar overflow
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
                        icon: Icons.update_outlined,
                        label: 'Actualizaciones',
                        value: '${_stats!['con_actualizaciones']}',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tarjeta de Offline Pendientes
                  if ((_stats!['pendientes_sync'] ?? 0) > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sync_problem, color: Colors.amber, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_stats!['pendientes_sync']} registros pendientes offline',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13),
                                ),
                                const Text(
                                  'Revisa el apartado de Sincronización para subirlos.',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Último registro
                  if (_stats!['ultimo_nombre'] != '-') ...[
                    _seccion('Último Registro'),
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
