import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_app_comunitaria/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReporteScreen extends StatefulWidget {
  const ReporteScreen({super.key});

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  final _dpiController = TextEditingController(text: AppSession.dpiUsuario ?? '');
  final _descripcionController = TextEditingController();
  final _latitudController = TextEditingController();
  final _longitudController = TextEditingController();
  final _direccionController = TextEditingController();

  List<Map<String, dynamic>> _tiposIncidente = [];
  int? _idTipoIncidente;
  bool _loading = false;
  Uint8List? _archivoEvidenciaBytes;
  String? _nombreEvidencia;
  String? _tipoEvidencia;

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  void initState() {
    super.initState();
    _cargarTiposIncidente();
  }

  @override
  void dispose() {
    _dpiController.dispose();
    _descripcionController.dispose();
    _latitudController.dispose();
    _longitudController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _cargarTiposIncidente() async {
    try {
      final data = await SupabaseService.client
          .from('tipos_incidente')
          .select()
          .order('nombre_tipo');

      setState(() {
        _tiposIncidente = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showMessage('Error al cargar tipos de incidente: $e');
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      var serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Activá la ubicación/GPS del dispositivo.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showMessage('Permiso de ubicación denegado.');
        return;
      }

      setState(() => _loading = true);

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitudController.text = position.latitude.toStringAsFixed(8);
      _longitudController.text = position.longitude.toStringAsFixed(8);

      try {
        final places = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (places.isNotEmpty) {
          final p = places.first;
          final partes = [
            p.street,
            p.subLocality,
            p.locality,
            p.subAdministrativeArea,
            p.administrativeArea,
          ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim()).toList();
          _direccionController.text = partes.join(', ');
        }
      } catch (_) {
        _direccionController.text = 'Lat: ${position.latitude}, Lng: ${position.longitude}';
      }

      _showMessage('Ubicación obtenida correctamente.');
    } catch (e) {
      _showMessage('Error al obtener ubicación: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _seleccionarEvidencia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'avi', 'mkv'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      final file = result.files.single;
      final ext = (file.extension ?? '').toLowerCase();
      final esVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
      final esImagen = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);

      if (!esVideo && !esImagen) {
        _showMessage('Seleccioná una imagen o video válido.');
        return;
      }

      setState(() {
        _archivoEvidenciaBytes = file.bytes;
        _nombreEvidencia = file.name;
        _tipoEvidencia = esVideo ? 'Video' : 'Imagen';
      });
    } catch (e) {
      _showMessage('Error al seleccionar archivo: $e');
    }
  }

  Future<String?> _subirEvidencia(int idReporte) async {
    if (_archivoEvidenciaBytes == null || _nombreEvidencia == null) return null;

    final dpi = _dpiController.text.trim();
    final extension = _nombreEvidencia!.split('.').last.toLowerCase();
    final storagePath = '$dpi/reporte_${idReporte}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await SupabaseService.client.storage.from('reportes').uploadBinary(
          storagePath,
          _archivoEvidenciaBytes!,
          fileOptions: const FileOptions(upsert: true),
        );

    return SupabaseService.client.storage.from('reportes').getPublicUrl(storagePath);
  }

  Future<void> _enviarReporte() async {
    final dpi = _dpiController.text.trim();
    final descripcion = _descripcionController.text.trim();

    if (dpi.length != 13 || descripcion.isEmpty || _idTipoIncidente == null) {
      _showMessage('Completá DPI, tipo de incidente y descripción.');
      return;
    }

    setState(() => _loading = true);

    try {
      final insertado = await SupabaseService.client.from('reportes').insert({
        'dpi_usuario': dpi,
        'id_tipo_incidente': _idTipoIncidente,
        'descripcion': descripcion,
        'latitud': double.tryParse(_latitudController.text.trim()),
        'longitud': double.tryParse(_longitudController.text.trim()),
        'direccion_incidente': _direccionController.text.trim().isEmpty ? null : _direccionController.text.trim(),
        'estado_reporte': AppSession.esDirectiva ? 'En Revisión' : 'Pendiente',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'tipo_evidencia': _tipoEvidencia,
      }).select('id_reporte').single();

      final idReporte = insertado['id_reporte'] as int;
      final evidenciaUrl = await _subirEvidencia(idReporte);

      if (evidenciaUrl != null) {
        await SupabaseService.client.from('reportes').update({
          'evidencia_url': evidenciaUrl,
          'tipo_evidencia': _tipoEvidencia,
        }).eq('id_reporte', idReporte);
      }

      if (!mounted) return;
      _descripcionController.clear();
      _latitudController.clear();
      _longitudController.clear();
      _direccionController.clear();
      setState(() {
        _archivoEvidenciaBytes = null;
        _nombreEvidencia = null;
        _tipoEvidencia = null;
      });
      _showMessage('Reporte enviado correctamente.');
    } catch (e) {
      _showMessage('Error al enviar reporte: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildUnderlineField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
      ),
    );
  }

  Widget _buildDropdownTipoIncidente() {
    return DropdownButtonFormField<int>(
      value: _idTipoIncidente,
      decoration: const InputDecoration(
        labelText: 'Tipo de incidente',
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
      ),
      items: _tiposIncidente.map((tipo) {
        return DropdownMenuItem<int>(
          value: tipo['id_tipo_incidente'] as int,
          child: Text(tipo['nombre_tipo'].toString()),
        );
      }).toList(),
      onChanged: (value) => setState(() => _idTipoIncidente = value),
    );
  }

  Widget _buildAsuntoContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _descripcionController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "Describe el problema...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Adjuntar imagen o video',
                icon: const Icon(Icons.attach_file, color: primaryColor),
                onPressed: _loading ? null : _seleccionarEvidencia,
              ),
              Expanded(
                child: Text(
                  _nombreEvidencia == null
                      ? 'Sin evidencia adjunta'
                      : '${_tipoEvidencia ?? 'Archivo'}: $_nombreEvidencia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              if (_nombreEvidencia != null)
                IconButton(
                  tooltip: 'Quitar archivo',
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _archivoEvidenciaBytes = null;
                            _nombreEvidencia = null;
                            _tipoEvidencia = null;
                          }),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _enviarReporte,
                icon: _loading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Enviar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                label: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 20),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, color: Colors.white)),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Formulario de Reportes', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    "FORMULARIO DE REPORTES",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 20),
                  _buildUnderlineField(
                    _dpiController,
                    "No. de DPI",
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownTipoIncidente(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _loading ? null : _obtenerUbicacionActual,
                          icon: const Icon(Icons.my_location, color: Colors.white),
                          label: const Text('Usar posición actual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildUnderlineField(_direccionController, "Dirección del reporte", maxLines: 2),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildUnderlineField(_latitudController, "Latitud", keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildUnderlineField(_longitudController, "Longitud", keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildAsuntoContainer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
