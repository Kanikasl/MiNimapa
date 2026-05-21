import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_comunitaria/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfile extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const EditProfile({super.key, required this.usuario});

  static Future<bool?> show(BuildContext context, Map<String, dynamic> usuario) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => EditProfile(usuario: usuario),
    );
  }

  @override
  State<EditProfile> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfile> {
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _telefonoController = TextEditingController();

  bool _loading = false;
  String? _fotoUrl;
  String? _archivoSeleccionado;

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  void initState() {
    super.initState();
    _nombresController.text = widget.usuario['nombres']?.toString() ?? '';
    _apellidosController.text = widget.usuario['apellidos']?.toString() ?? '';
    final telefonoGuardado = widget.usuario['telefono']?.toString() ?? '';
    final soloNumeros = telefonoGuardado.replaceAll(RegExp(r'[^0-9]'), '');
    _telefonoController.text = soloNumeros.startsWith('502') ? soloNumeros.substring(3) : soloNumeros;
    _fotoUrl = widget.usuario['foto_perfil_url']?.toString();
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarYSubirFoto() async {
    final dpi = AppSession.dpiUsuario;
    if (dpi == null) {
      _mostrarMensaje('No hay usuario en sesión.');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      setState(() => _loading = true);

      final bytes = result.files.single.bytes!;
      final extension = result.files.single.extension ?? 'jpg';
      final fileName = 'perfil_$dpi.${extension.toLowerCase()}';
      final storagePath = '$dpi/$fileName';

      await SupabaseService.client.storage.from('perfiles').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = SupabaseService.client.storage.from('perfiles').getPublicUrl(storagePath);

      setState(() {
        _fotoUrl = publicUrl;
        _archivoSeleccionado = result.files.single.name;
      });

      _mostrarMensaje('Fotografía cargada correctamente.');
    } catch (e) {
      _mostrarMensaje('Error al cargar fotografía: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _eliminarFoto() async {
    final dpi = AppSession.dpiUsuario;
    if (dpi == null) return;

    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('usuarios').update({'foto_perfil_url': null}).eq('dpi', dpi);
      setState(() {
        _fotoUrl = null;
        _archivoSeleccionado = null;
      });
      _mostrarMensaje('Fotografía eliminada.');
    } catch (e) {
      _mostrarMensaje('Error al eliminar fotografía: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guardarDatos() async {
    final dpi = AppSession.dpiUsuario;
    if (dpi == null) {
      _mostrarMensaje('No hay usuario en sesión.');
      return;
    }

    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final telefono = _telefonoController.text.trim();

    if (nombres.isEmpty || apellidos.isEmpty) {
      _mostrarMensaje('Nombres y apellidos son obligatorios.');
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('usuarios').update({
        'nombres': nombres,
        'apellidos': apellidos,
        'telefono': telefono.isEmpty ? null : '+502$telefono',
        'foto_perfil_url': _fotoUrl,
      }).eq('dpi', dpi);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _mostrarMensaje('Error al guardar perfil: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('EDITAR DATOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 20),
              _buildUnderlineField(_nombresController, 'Nombre(s)'),
              const SizedBox(height: 16),
              _buildUnderlineField(_apellidosController, 'Apellido(s)'),
              const SizedBox(height: 16),
              _buildPhoneField(),
              const SizedBox(height: 22),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: (_fotoUrl != null && _fotoUrl!.isNotEmpty)
                        ? NetworkImage(_fotoUrl!)
                        : const AssetImage('assets/perfil.jpg') as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fotografía de perfil', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Text(
                          _archivoSeleccionado ?? ((_fotoUrl != null && _fotoUrl!.isNotEmpty) ? 'Foto cargada' : 'Sin fotografía'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cargar fotografía',
                    icon: const Icon(Icons.upload_file, color: primaryColor),
                    onPressed: _loading ? null : _seleccionarYSubirFoto,
                  ),
                  IconButton(
                    tooltip: 'Eliminar fotografía',
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _loading ? null : _eliminarFoto,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _loading ? null : _guardarDatos,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('GUARDAR DATOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildPhoneField() {
    return TextField(
      controller: _telefonoController,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
      decoration: const InputDecoration(
        prefixText: '+502 ',
        hintText: 'No. de Teléfono',
        helperText: 'Solo 8 dígitos. Ejemplo: 37767071',
        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
        contentPadding: EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }

  Widget _buildUnderlineField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }
}
