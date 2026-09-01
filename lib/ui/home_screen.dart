import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offdata/providers/app_provider.dart';
import 'package:offdata/models/persona.dart';
import 'package:offdata/ui/theme.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OffData - Offline First'),
        actions: [
          const SyncStatusIndicator(),
        ],
      ),
      body: Column(
        children: [
          const MetricsHeader(),
          Expanded(
            child: Consumer<AppProvider>(
              builder: (context, provider, child) {
                if (provider.personas.isEmpty) {
                  return const Center(child: Text('No hay datos disponibles'));
                }
                return ListView.builder(
                  itemCount: provider.personas.length,
                  itemBuilder: (context, index) {
                    final persona = provider.personas[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(persona.nombreCompleto),
                        subtitle: Text(persona.cedula),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonaDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPersonaDialog(BuildContext context) {
    final nombreController = TextEditingController();
    final cedulaController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar Persona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre Completo')),
            TextField(controller: cedulaController, decoration: const InputDecoration(labelText: 'Cédula')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<AppProvider>(context, listen: false);
              final cedula = cedulaController.text;
              
              // Duplicate Check Logic
              final exists = await provider.checkDuplicate(cedula);
              if (exists) {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Duplicado detectado'),
                    content: Text('La persona con cédula $cedula ya existe localmente.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
                    ],
                  ),
                );
              } else {
                await provider.addPersona(Persona(
                  id: const Uuid().v4(),
                  cedula: cedula,
                  nombreCompleto: nombreController.text,
                  fechaNacimiento: '1990-01-01',
                  tipoVia: 'Calle',
                  numeroVia: '123',
                  barrio: 'Centro',
                  ciudad: 'Bogotá',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  deviceId: 'web-entry',
                ));
                if (context.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class MetricsHeader extends StatelessWidget {
  const MetricsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final total = context.select<AppProvider, int>((p) => p.totalPersonas);
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surfaceColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetricTile(label: 'Total Personas', value: total.toString()),
          const _MetricTile(label: 'Estado', value: 'Activo'),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.accentColor)),
      ],
    );
  }
}

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AppProvider>().syncStatus;
    Color color = Colors.grey;
    IconData icon = Icons.cloud_off;

    if (status?.connected == true) {
      color = Colors.green;
      icon = Icons.cloud_done;
    } else if (status?.uploading == true || status?.downloading == true) {
      color = Colors.orange;
      icon = Icons.sync;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Tooltip(
        message: status?.connected == true ? 'Conectado' : 'Sincronizando/Desconectado',
        child: Icon(icon, color: color),
      ),
    );
  }
}
