import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/persona.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/persona_repository.dart';
import '../../sync/sync_controller.dart';

class MobilePersonaFormView extends StatefulWidget {
  final Persona? persona;
  final bool esDuplicado;

  const MobilePersonaFormView({
    super.key,
    this.persona,
    this.esDuplicado = false,
  });

  @override
  State<MobilePersonaFormView> createState() => _MobilePersonaFormViewState();
}

class _MobilePersonaFormViewState extends State<MobilePersonaFormView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _cedulaController;
  late TextEditingController _nombreController;
  late TextEditingController _telefonoController;
  late TextEditingController _numeroViaController;
  late TextEditingController _barrioController;
  late TextEditingController _ciudadController;

  DateTime? _fechaNacimiento;
  String _tipoViaSeleccionado = 'Calle';
  bool _guardando = false;

  // Control de cédula duplicada por el mismo encuestador
  bool _cedulaYaRegistrada = false;
  bool _verificandoCedula = false;
  Timer? _debounceTimer;

  static const List<String> _tiposVia = [
    'Calle', 'Carrera', 'Avenida', 'Diagonal', 'Transversal', 'Circular', 'Vía', 'Manzana'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _cedulaController = TextEditingController(text: p?.cedula ?? '');
    _nombreController = TextEditingController(text: p?.nombreCompleto ?? '');
    _telefonoController = TextEditingController(text: p?.telefono ?? '');
    _numeroViaController = TextEditingController(text: p?.numeroVia ?? '');
    _barrioController = TextEditingController(text: p?.barrio ?? '');
    _ciudadController = TextEditingController(text: p?.ciudad ?? '');
    _tipoViaSeleccionado = (p?.tipoVia != null && _tiposVia.contains(p!.tipoVia)) ? p.tipoVia : 'Calle';

    if (p?.fechaNacimiento != null && p!.fechaNacimiento.isNotEmpty) {
      _fechaNacimiento = DateTime.tryParse(p.fechaNacimiento);
    }

    // Solo verificar cédula en modo nuevo registro
    if (widget.persona == null) {
      _cedulaController.addListener(_onCedulaChanged);
    }
  }

  void _onCedulaChanged() {
    final cedula = _cedulaController.text.trim();
    _debounceTimer?.cancel();
    if (cedula.length < 5) {
      // Cédula muy corta: limpiar estado
      if (_cedulaYaRegistrada || _verificandoCedula) {
        setState(() {
          _cedulaYaRegistrada = false;
          _verificandoCedula = false;
        });
      }
      return;
    }
    // Debounce de 600ms para no llamar en cada tecla
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _verificarCedula(cedula);
    });
  }

  Future<void> _verificarCedula(String cedula) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final encuestadorId = auth.userId;
    if (encuestadorId.isEmpty) return;

    setState(() => _verificandoCedula = true);
    final repo = context.read<PersonaRepository>();
    final yaExiste = await repo.encuestadorYaRegistroCedula(cedula, encuestadorId);
    if (!mounted) return;
    setState(() {
      _cedulaYaRegistrada = yaExiste;
      _verificandoCedula = false;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cedulaController.removeListener(_onCedulaChanged);
    _cedulaController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _numeroViaController.dispose();
    _barrioController.dispose();
    _ciudadController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _fechaNacimiento ?? DateTime(1990, 1, 1),
        firstDate: DateTime(1920),
        lastDate: DateTime.now(),
        helpText: 'FECHA DE NACIMIENTO',
        cancelText: 'CANCELAR',
        confirmText: 'CONFIRMAR',
      );
      if (picked != null) {
        setState(() => _fechaNacimiento = picked);
      }
    } catch (e) {
      debugPrint('Error en DatePicker: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Bloqueo duro: el mismo encuestador no puede registrar la misma cédula dos veces
    if (widget.persona == null && _cedulaYaRegistrada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.block, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ya registraste esta cédula. No puedes ingresarla dos veces.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFFB71C1C),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_fechaNacimiento == null && !widget.esDuplicado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona la fecha de nacimiento'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    final repo = context.read<PersonaRepository>();
    final syncController = context.read<SyncController>();
    final auth = context.read<AuthProvider>();
    final bool isOnline = syncController.hasInternet;

    final encId = auth.userId;
    final encNombre = auth.name;
    final encEmail = auth.email;

    try {
      if (widget.persona == null) {
        final nueva = Persona(
          id: const Uuid().v4(),
          cedula: _cedulaController.text.trim(),
          nombreCompleto: _nombreController.text.trim(),
          fechaNacimiento: _fechaNacimiento != null
              ? _fechaNacimiento!.toIso8601String().split('T')[0]
              : '1990-01-01',
          tipoVia: _tipoViaSeleccionado,
          numeroVia: _numeroViaController.text.trim(),
          barrio: _barrioController.text.trim(),
          ciudad: _ciudadController.text.trim(),
          telefono: _telefonoController.text.trim(),
          esPrincipal: true,
          registroNumero: 1,
          isSynced: isOnline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deviceId: 'mobile-${DateTime.now().millisecondsSinceEpoch}',
          encuestadorId: encId,
          encuestadorNombre: encNombre,
          encuestadorEmail: encEmail,
        );

        final resultado = await repo.guardarRegistroEncuesta(
          nueva: nueva,
          isOnline: isOnline,
        );

        if (!mounted) return;

        final tipo = resultado['tipo'];
        String mensaje = 'Registro guardado exitosamente';
        if (!isOnline) {
          mensaje = 'Registro guardado localmente (pendiente de sincronización)';
        } else if (tipo == 'modificado') {
          mensaje = 'Registro guardado y reporte de actualización enviado al Administrador';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: isOnline ? Colors.green : Colors.blueGrey,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (widget.esDuplicado) {
        final actualizada = Persona(
          id: const Uuid().v4(),
          cedula: widget.persona!.cedula,
          nombreCompleto: widget.persona!.nombreCompleto,
          fechaNacimiento: widget.persona!.fechaNacimiento,
          tipoVia: _tipoViaSeleccionado,
          numeroVia: _numeroViaController.text.trim(),
          barrio: _barrioController.text.trim(),
          ciudad: _ciudadController.text.trim(),
          telefono: _telefonoController.text.trim(),
          esPrincipal: true,
          registroNumero: widget.persona!.registroNumero + 1,
          isSynced: isOnline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deviceId: 'mobile-${DateTime.now().millisecondsSinceEpoch}',
          encuestadorId: encId,
          encuestadorNombre: encNombre,
          encuestadorEmail: encEmail,
        );

        await repo.actualizarConHistorial(
          existente: widget.persona!,
          nueva: actualizada,
        );

        if (isOnline) {
          await repo.sincronizarPersonaManual(actualizada);
        }
      } else {
        final editada = Persona(
          id: widget.persona!.id,
          cedula: widget.persona!.cedula,
          nombreCompleto: widget.persona!.nombreCompleto,
          fechaNacimiento: widget.persona!.fechaNacimiento,
          tipoVia: _tipoViaSeleccionado,
          numeroVia: _numeroViaController.text.trim(),
          barrio: _barrioController.text.trim(),
          ciudad: _ciudadController.text.trim(),
          telefono: _telefonoController.text.trim(),
          esPrincipal: widget.persona!.esPrincipal,
          registroNumero: widget.persona!.registroNumero,
          syncVersion: widget.persona!.syncVersion,
          isSynced: isOnline,
          createdAt: widget.persona!.createdAt,
          updatedAt: DateTime.now(),
          deviceId: widget.persona!.deviceId,
          encuestadorId: widget.persona!.encuestadorId.isNotEmpty ? widget.persona!.encuestadorId : encId,
          encuestadorNombre: widget.persona!.encuestadorNombre.isNotEmpty ? widget.persona!.encuestadorNombre : encNombre,
          encuestadorEmail: widget.persona!.encuestadorEmail.isNotEmpty ? widget.persona!.encuestadorEmail : encEmail,
        );

        await repo.savePersona(editada);

        if (isOnline) {
          await repo.sincronizarPersonaManual(editada);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  bool get _camposInmutables => widget.esDuplicado;
  bool get _esNuevo => widget.persona == null;

  @override
  Widget build(BuildContext context) {
    String titulo = 'Nuevo Registro';
    if (widget.esDuplicado) titulo = 'Actualizar Datos';
    if (widget.persona != null && !widget.esDuplicado) titulo = 'Editar Registro';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          if (widget.esDuplicado)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('Actualización #${(widget.persona?.registroNumero ?? 0) + 1}'),
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                labelStyle: const TextStyle(color: Colors.blueAccent, fontSize: 11),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          children: [
            if (widget.esDuplicado)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nombre y fecha de nacimiento bloqueados — se preservan de la identidad original.',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // ─ IDENTIFICACIÓN ─────────────────────────────────────
            _buildSection('Identificación'),
            TextFormField(
              controller: _cedulaController,
              enabled: _esNuevo,
              decoration: _deco(
                'Cédula de Ciudadanía',
                icon: Icons.badge_outlined,
                suffix: _esNuevo && _verificandoCedula
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                        ),
                      )
                    : _esNuevo && _cedulaYaRegistrada
                        ? const Icon(Icons.block, color: Color(0xFFEF5350), size: 20)
                        : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v!.trim().isEmpty ? 'La cédula es requerida' : null,
            ),

            // Banner de alerta inline bajo el campo de cédula
            if (_esNuevo && _cedulaYaRegistrada)
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Color(0xFFEF5350), size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Ya registraste esta cédula anteriormente. No es posible ingresarla de nuevo.',
                        style: TextStyle(
                          color: Color(0xFFEF9A9A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // ─ NOMBRE ─────────────────────────────────────────────
            TextFormField(
              controller: _nombreController,
              enabled: _esNuevo,
              decoration: _deco(
                'Nombre Completo',
                icon: Icons.person_outline,
                suffix: _camposInmutables ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey) : null,
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => _esNuevo && v!.trim().isEmpty ? 'El nombre es requerido' : null,
            ),
            const SizedBox(height: 14),

            // ─ FECHA NACIMIENTO (date picker) ─────────────────────
            InkWell(
              onTap: _camposInmutables ? null : _seleccionarFecha,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: _deco(
                  'Fecha de Nacimiento',
                  icon: Icons.cake_outlined,
                  suffix: _camposInmutables
                      ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                      : const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent),
                ),
                child: Text(
                  _fechaNacimiento != null
                      ? _formatFecha(_fechaNacimiento!)
                      : widget.esDuplicado
                          ? _formatFechaNacimientoExistente()
                          : 'Toca para seleccionar',
                  style: TextStyle(
                    color: _fechaNacimiento != null || widget.esDuplicado
                        ? Colors.white
                        : Colors.grey,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─ CONTACTO ───────────────────────────────────────────
            _buildSection('Contacto'),
            TextFormField(
              controller: _telefonoController,
              decoration: _deco('Celular (10 dígitos)', icon: Icons.phone_outlined),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (v.length != 10) return 'Debe tener 10 dígitos';
                if (!v.startsWith('3')) return 'Debe comenzar con 3 (celular colombiano)';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ─ DIRECCIÓN ESTRUCTURADA ──────────────────────────────
            _buildSection('Dirección'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    value: _tipoViaSeleccionado,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Tipo Vía',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                      ),
                    ),
                    items: _tiposVia
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _tipoViaSeleccionado = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: _numeroViaController,
                    decoration: InputDecoration(
                      labelText: 'Número / Vía',
                      hintText: '15 #30-20',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                      ),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barrioController,
              decoration: _deco('Barrio', icon: Icons.location_city_outlined),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ciudadController,
              decoration: _deco('Ciudad / Municipio', icon: Icons.map_outlined),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v!.trim().isEmpty ? 'La ciudad es requerida' : null,
            ),
            const SizedBox(height: 28),

            // ─ BOTÓN GUARDAR ──────────────────────────────────────
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (widget.persona == null && _cedulaYaRegistrada)
                      ? Colors.grey
                      : widget.esDuplicado
                          ? Colors.green
                          : Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_guardando || (widget.persona == null && _cedulaYaRegistrada)) ? null : _save,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : (widget.persona == null && _cedulaYaRegistrada)
                        ? const Icon(Icons.block)
                        : Icon(widget.esDuplicado ? Icons.update : Icons.save_outlined),
                label: Text(
                  (widget.persona == null && _cedulaYaRegistrada)
                      ? 'CÉDULA YA REGISTRADA'
                      : widget.esDuplicado
                          ? 'GUARDAR ACTUALIZACIÓN'
                          : 'GUARDAR REGISTRO',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, {IconData? icon, String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.blueAccent.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  String _formatFechaNacimientoExistente() {
    final f = DateTime.tryParse(widget.persona?.fechaNacimiento ?? '');
    return f != null ? _formatFecha(f) : 'No registrada';
  }
}
