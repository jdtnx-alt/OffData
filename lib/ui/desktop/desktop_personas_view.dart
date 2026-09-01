import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/persona_repository.dart';
import '../../models/persona.dart';

class DesktopPersonasView extends StatelessWidget {
  const DesktopPersonasView({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<PersonaRepository>();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registros de Personas', 
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {}, 
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: const Icon(Icons.add), 
                label: const Text('NUEVO REGISTRO'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: StreamBuilder<List<Persona>>(
              stream: repository.watchPersonas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final personas = snapshot.data ?? [];
                
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('CÉDULA', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('NOMBRE COMPLETO', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('CIUDAD', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ACCIONES', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: personas.map((p) => DataRow(cells: [
                        DataCell(Text(p.cedula)),
                        DataCell(Text(p.nombreCompleto)),
                        DataCell(Text(p.ciudad)),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18), 
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), 
                                onPressed: () => repository.deletePersona(p.id),
                              ),
                            ],
                          ),
                        ),
                      ])).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
