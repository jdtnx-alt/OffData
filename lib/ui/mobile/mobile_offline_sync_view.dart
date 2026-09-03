import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/persona.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/persona_repository.dart';
import '../../sync/sync_controller.dart';
import '../widgets/network_badge.dart';
import 'mobile_persona_form_view.dart';

class MobileOfflineSyncView extends StatefulWidget {
  const MobileOfflineSyncView({super.key});

  @override
  State<MobileOfflineSyncView> createState() => _MobileOfflineSyncViewState();
}

class _MobileOfflineSyncViewState extends State<MobileOfflineSyncView> {
  final Set<String> _syncingIds = {};
  bool _syncingAll = false;
  bool _cancelRequested = false;

  void _cancelarSincronizacion() {
    setState(() {
      _cancelRequested = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Cancelando sincronización en curso...'),
          ],
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _sincronizarUno(Persona persona) async {
    final syncController = context.read<SyncController>();
    if (!syncController.hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('No hay conexión a Internet. Conéctate para sincronizar.'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _syncingIds.add(persona.id));
    final repo = context.read<PersonaRepository>();

    try {
      final ok = await repo.sincronizarPersonaManual(persona);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(ok ? Icons.check_circle_outline : Icons.info_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(ok
                    ? 'Registro de ${persona.nombreCompleto} sincronizado'
                    : 'Registro guardado y actualizado localmente'),
              ],
            ),
            backgroundColor: ok ? Colors.green : Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Error al sincronizar: $e'),
              ],
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingIds.remove(persona.id));
    }
  }

  Future<void> _sincronizarTodos(List<Persona> personas) async {
    if (personas.isEmpty) return;
    final syncController = context.read<SyncController>();
    if (!syncController.hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Sin conexión a Internet. No se puede sincronizar con la base de datos.'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _syncingAll = true;
      _cancelRequested = false;
    });

    final repo = context.read<PersonaRepository>();
    int exitosos = 0;

    try {
      for (final p in personas) {
        if (_cancelRequested) break;
        final ok = await repo.sincronizarPersonaManual(p);
        if (ok) exitosos++;
      }

      if (mounted) {
        if (_cancelRequested) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Sincronización detenida. Se subieron $exitosos registros.'),
                ],
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cloud_done, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('$exitosos registros sincronizados exitosamente'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Error durante la sincronización: $e'),
              ],
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingAll = false;
          _cancelRequested = false;
        });
      }
    }
  }

  void _descartarRegistro(Persona persona) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 36),
        title: const Text('Descartar de Pendientes', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
        content: Text(
          '¿Deseas marcar a "${persona.nombreCompleto}" como descartado de la sincronización offline?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('VOLVER'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await context.read<PersonaRepository>().deletePersona(persona.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Registro eliminado de la cola'),
                      ],
                    ),
                    backgroundColor: Colors.blueGrey,
                  ),
                );
              }
            },
            child: const Text('DESCARTAR'),
          ),
        ],
      ),
    );
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
              isAdmin ? 'Sincronización Global' : 'Mi Sincronización',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              isAdmin ? 'Todos los registros pendientes en la plataforma' : 'Tus registros guardados sin internet',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: const [
          NetworkBadge(),
          SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      body: StreamBuilder<List<Persona>>(
        stream: repo.watchOfflinePersonas(encuestadorId: isAdmin ? null : auth.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final offlineList = snapshot.data ?? [];

          if (offlineList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_done, size: 64, color: Colors.green),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Todo Sincronizado',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No tienes registros pendientes de sincronización offline. Todos los datos están en la base de datos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Banner superior con botones de acción (Subir todos / Cancelar sincronización)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${offlineList.length} pendiente${offlineList.length > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Hechos sin conexión',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    if (_syncingAll)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _cancelarSincronizacion,
                        icon: const Icon(Icons.stop_circle_outlined, size: 15),
                        label: const Text('CANCELAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _sincronizarTodos(offlineList),
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('SUBIR TODOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              // Lista de registros pendientes
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: offlineList.length,
                  itemBuilder: (context, index) {
                    final p = offlineList[index];
                    final isSyncing = _syncingIds.contains(p.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                                  child: Text(
                                    p.nombreCompleto.isNotEmpty ? p.nombreCompleto[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.nombreCompleto,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text('CC ${p.cedula}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                                  tooltip: 'Descartar de pendientes',
                                  onPressed: isSyncing || _syncingAll ? null : () => _descartarRegistro(p),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (p.ciudad.isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                p.ciudad,
                                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (p.telefono.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.phone_outlined, size: 13, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(p.telefono, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    // Botón EDITAR antes de sincronizar
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.white24),
                                        foregroundColor: Colors.white70,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MobilePersonaFormView(persona: p),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: const Text('EDITAR', style: TextStyle(fontSize: 11)),
                                    ),
                                    const SizedBox(width: 8),

                                    // Botón SUBIR
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: isSyncing || _syncingAll ? null : () => _sincronizarUno(p),
                                      icon: isSyncing
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.cloud_upload_outlined, size: 14),
                                      label: const Text('SUBIR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
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
    );
  }
}
