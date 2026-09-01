import 'package:flutter/material.dart';

class DuplicateDialog extends StatelessWidget {
  final String cedula;

  const DuplicateDialog({super.key, required this.cedula});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Cédula Duplicada'),
        ],
      ),
      content: Text('Ya existe una persona registrada con la cédula: $cedula. ¿Qué desea hacer?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'view'),
          child: const Text('Ver Registro'),
        ),
      ],
    );
  }
}
