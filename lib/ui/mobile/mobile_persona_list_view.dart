import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/persona.dart';
import '../../repositories/persona_repository.dart';
import 'mobile_persona_detail_view.dart';
import 'mobile_persona_form_view.dart';
import '../widgets/network_badge.dart';

class MobilePersonaListView extends StatelessWidget {
  const MobilePersonaListView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PersonaRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OffData', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Registro de Personas', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: const [
          NetworkBadge(),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      body: StreamBuilder<List<Persona>>(
        stream: repo.watchPersonas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final personas = snapshot.data ?? [];

          if (personas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 72, color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 16),
                  const Text('Sin registros aún', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Presiona + para registrar una persona', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: personas.length,
            itemBuilder: (context, index) {
              final p = personas[index];
              return _PersonaCard(persona: p);
            },
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
}

class _PersonaCard extends StatelessWidget {
  final Persona persona;
  const _PersonaCard({required this.persona});

  @override
  Widget build(BuildContext context) {
    final p = persona;
    final tieneActualizaciones = p.registroNumero > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                child: Text(
                  p.nombreCompleto.isNotEmpty ? p.nombreCompleto[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
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
                            child: Text(
                              '#${p.registroNumero}',
                              style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
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
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
