import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/persona.dart';
import '../../models/reporte_cambio.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/persona_repository.dart';
import 'mobile_persona_detail_view.dart';
import 'mobile_persona_form_view.dart';
import '../widgets/network_badge.dart';

class MobilePersonaListView extends StatefulWidget {
  const MobilePersonaListView({super.key});

  @override
  State<MobilePersonaListView> createState() => _MobilePersonaListViewState();
}

class _MobilePersonaListViewState extends State<MobilePersonaListView> {
  String _searchQuery = '';
  bool _soloDuplicados = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final repo = context.watch<PersonaRepository>();
    final isAdmin = auth.isAdmin;

    // Si es encuestador, solo ve los suyos. Si es admin, ve absolutamente todos.
    final stream = repo.watchPersonas(encuestadorId: isAdmin ? null : auth.userId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'Panel General de Personas' : 'Mis Registros',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              isAdmin ? 'Acceso total de Administrador' : 'Encuestador: ${auth.name}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            StreamBuilder<int>(
              stream: repo.watchConteoReportesNoLeidos(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return IconButton(
                  tooltip: 'Reportes de cambios entre encuestadores',
                  onPressed: () => _mostrarReportesCambios(context, repo),
                  icon: Badge(
                    isLabelVisible: count > 0,
                    backgroundColor: Colors.redAccent,
                    label: Text('$count'),
                    child: const Icon(Icons.notification_important_outlined, color: Colors.orangeAccent),
                  ),
                );
              },
            ),
          const NetworkBadge(),
          if (isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Opciones de Administrador',
              color: const Color(0xFF1E293B),
              onSelected: (val) {
                if (val == 'limpiar_todo') {
                  _confirmarLimpiarTodo(context, repo);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'limpiar_todo',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18),
                      SizedBox(width: 10),
                      Text('Limpiar todos los registros', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      body: StreamBuilder<List<Persona>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final todas = snapshot.data ?? [];

          // Filtrar por búsqueda y si admin activó filtro de duplicados
          final personasFiltradas = todas.where((p) {
            final q = _searchQuery.toLowerCase().trim();
            final coincideBusqueda = q.isEmpty ||
                p.nombreCompleto.toLowerCase().contains(q) ||
                p.cedula.toLowerCase().contains(q) ||
                p.ciudad.toLowerCase().contains(q) ||
                p.encuestadorNombre.toLowerCase().contains(q);

            if (!coincideBusqueda) return false;

            if (_soloDuplicados) {
              return p.registroNumero > 1;
            }
            return true;
          }).toList();

          final countDuplicados = todas.where((p) => p.registroNumero > 1).length;

          return Column(
            children: [
              // Barra de búsqueda y filtros
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: isAdmin
                            ? 'Buscar por nombre, cédula, ciudad o encuestador...'
                            : 'Buscar por nombre, cédula o ciudad...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text('Todos (${todas.length})', style: const TextStyle(fontSize: 12)),
                            selected: !_soloDuplicados,
                            onSelected: (val) {
                              if (val) setState(() => _soloDuplicados = false);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: _soloDuplicados ? Colors.white : Colors.orangeAccent,
                            ),
                            label: Text(
                              'Con Múltiples Registros ($countDuplicados)',
                              style: TextStyle(
                                fontSize: 12,
                                color: _soloDuplicados ? Colors.white : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: _soloDuplicados,
                            selectedColor: Colors.orange.shade800,
                            onSelected: (val) {
                              setState(() => _soloDuplicados = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Lista de registros
              Expanded(
                child: personasFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 72, color: Colors.white.withValues(alpha: 0.15)),
                            const SizedBox(height: 16),
                            Text(
                              _soloDuplicados
                                  ? 'No hay personas con múltiples registros'
                                  : (todas.isEmpty ? 'Sin registros aún' : 'No se encontraron resultados'),
                              style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            if (todas.isEmpty)
                              const Text('Presiona + para registrar una persona', style: TextStyle(color: Colors.white38, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        itemCount: personasFiltradas.length,
                        itemBuilder: (context, index) {
                          final p = personasFiltradas[index];
                          return _PersonaCard(persona: p, isAdmin: isAdmin);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MobilePersonaFormView()),
        ),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo Registro'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  void _mostrarReportesCambios(BuildContext context, PersonaRepository repo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<List<ReporteCambio>>(
              stream: repo.watchReportesCambios(),
              builder: (context, snapshot) {
                final reportes = snapshot.data ?? [];
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined, color: Colors.orangeAccent, size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Reportes de Actualizaciones entre Encuestadores',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          if (reportes.any((r) => !r.leidoAdmin))
                            TextButton(
                              onPressed: () => repo.marcarTodosReportesLeidos(),
                              child: const Text('Marcar leídos', style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    Expanded(
                      child: reportes.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 48),
                                  SizedBox(height: 12),
                                  Text(
                                    'No hay reportes de cambios pendientes',
                                    style: TextStyle(color: Colors.white60, fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Cuando un encuestador actualice datos de otro encuestador, aparecerá aquí.',
                                    style: TextStyle(color: Colors.white38, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: reportes.length,
                              itemBuilder: (context, idx) {
                                final rep = reportes[idx];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: rep.leidoAdmin
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : Colors.orange.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: rep.leidoAdmin
                                          ? Colors.white10
                                          : Colors.orange.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                rep.nombrePersona,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'CC ${rep.cedula}',
                                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.sync_alt, size: 14, color: Colors.orangeAccent),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Actualizado por ${rep.encuestadorNombre} (previamente por ${rep.encuestadorAnteriorNombre})',
                                                style: const TextStyle(
                                                  color: Colors.orangeAccent,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Modificaciones:\n${rep.camposModificados}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white70,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${rep.fecha.day.toString().padLeft(2, '0')}/${rep.fecha.month.toString().padLeft(2, '0')}/${rep.fecha.year} ${rep.fecha.hour.toString().padLeft(2, '0')}:${rep.fecha.minute.toString().padLeft(2, '0')}',
                                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                                            ),
                                            if (!rep.leidoAdmin)
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                ),
                                                onPressed: () => repo.marcarReporteLeido(rep.id),
                                                icon: const Icon(Icons.check, size: 14, color: Colors.greenAccent),
                                                label: const Text(
                                                  'Marcar visto',
                                                  style: TextStyle(fontSize: 11, color: Colors.greenAccent),
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
            );
          },
        );
      },
    );
  }

  void _confirmarLimpiarTodo(BuildContext context, PersonaRepository repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Limpiar Base de Datos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar TODOS los registros de personas, historiales y reportes?\n\nLa aplicación quedará completamente en blanco y limpia.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
              await repo.limpiarTodosLosRegistros();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todos los registros han sido eliminados. Plataforma en blanco.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('LIMPIAR TODO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final Persona persona;
  final bool isAdmin;
  const _PersonaCard({required this.persona, required this.isAdmin});

  void _confirmarEliminarPersona(BuildContext context, Persona p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Eliminar Persona', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Deseas eliminar a ${p.nombreCompleto} (CC ${p.cedula})?\n\nSe eliminará este registro y todo su historial de la plataforma.',
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
              }
            },
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('ELIMINAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = persona;
    final tieneActualizaciones = p.registroNumero > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: tieneActualizaciones && isAdmin
            ? BorderSide(color: Colors.orange.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MobilePersonaDetailView(persona: p)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: tieneActualizaciones && isAdmin
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.blueAccent.withValues(alpha: 0.15),
                child: Text(
                  p.nombreCompleto.isNotEmpty ? p.nombreCompleto[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: tieneActualizaciones && isAdmin ? Colors.orange : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Datos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.nombreCompleto,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tieneActualizaciones)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history, size: 12, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  '${p.registroNumero} registros',
                                  style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CC ${p.cedula}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    if (p.ciudad.isNotEmpty || p.telefono.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (p.ciudad.isNotEmpty) p.ciudad,
                            if (p.telefono.isNotEmpty) 'Tel: ${p.telefono}',
                          ].join(' • '),
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (isAdmin)
                      FutureBuilder<List<String>>(
                        future: context.read<PersonaRepository>().getEncuestadoresPorCedula(p.cedula),
                        builder: (context, encSnapshot) {
                          final encList = encSnapshot.data ?? (p.encuestadorNombre.isNotEmpty ? [p.encuestadorNombre] : []);
                          if (encList.isEmpty) return const SizedBox.shrink();

                          final bool varios = encList.length > 1;
                          final texto = varios
                              ? 'Entrevistada por: ${encList.join(' y ')}'
                              : 'Encuestador: ${encList.first}';

                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  varios ? Icons.group_outlined : Icons.person_pin_outlined,
                                  size: 13,
                                  color: varios ? Colors.orangeAccent : Colors.blueAccent,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    texto,
                                    style: TextStyle(
                                      color: varios ? Colors.orangeAccent : Colors.blueAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                  tooltip: 'Eliminar registro',
                  onPressed: () => _confirmarEliminarPersona(context, p),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
