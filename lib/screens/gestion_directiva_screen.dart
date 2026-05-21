import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:app_comunitaria/widgets/ampliable_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_comunitaria/services/supabase_service.dart';

class GestionDirectivaScreen extends StatefulWidget {
  const GestionDirectivaScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<GestionDirectivaScreen> createState() => _GestionDirectivaScreenState();
}

class _GestionDirectivaScreenState extends State<GestionDirectivaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.esDirectiva) {
      return const Scaffold(
        body: Center(child: Text('Acceso denegado. Solo Directiva o Admin.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: GestionDirectivaScreen.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Gestión Directiva'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.assignment), text: 'Reportes'),
            Tab(icon: Icon(Icons.handyman), text: 'Proyectos'),
            Tab(icon: Icon(Icons.campaign), text: 'Anuncios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GestionReportesTab(),
          _GestionProyectosTab(),
          _GestionAnunciosTab(),
        ],
      ),
    );
  }
}

class _GestionReportesTab extends StatefulWidget {
  const _GestionReportesTab();

  @override
  State<_GestionReportesTab> createState() => _GestionReportesTabState();
}

class _GestionReportesTabState extends State<_GestionReportesTab> {
  late Future<List<Map<String, dynamic>>> _future;
  final List<String> _estados = const [
    'Pendiente',
    'En Revisión',
    'Solucionado',
    'Reparado',
    'Activo',
    'Bloqueado',
    'Terminado',
    'En espera',
    'Ejecutando',
  ];

  @override
  void initState() {
    super.initState();
    _future = _cargarReportes();
  }

  Future<List<Map<String, dynamic>>> _cargarReportes() async {
    final data = await SupabaseService.client
        .from('reportes')
        .select('id_reporte, dpi_usuario, descripcion, direccion_incidente, latitud, longitud, evidencia_url, tipo_evidencia, estado_reporte, fecha_reporte, fecha_actualizacion, tipos_incidente(nombre_tipo), usuarios(nombres, apellidos, telefono)')
        .order('fecha_reporte', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _actualizarEstado(int idReporte, String estado) async {
    try {
      await SupabaseService.client.from('reportes').update({
        'estado_reporte': estado,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      }).eq('id_reporte', idReporte);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reporte actualizado a $estado')),
      );
      final nuevoFuture = _cargarReportes();
      setState(() {
        _future = nuevoFuture;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar reporte: $e')),
      );
    }
  }

  Future<void> _confirmarEstado(int idReporte, String estado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar reporte'),
        content: Text('¿Cambiar el estado del reporte a "$estado"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GestionDirectivaScreen.primaryColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) await _actualizarEstado(idReporte, estado);
  }


  Future<void> _eliminarReporte(int idReporte) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: Text('¿Eliminar definitivamente el reporte #$idReporte?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await SupabaseService.client.from('reportes').delete().eq('id_reporte', idReporte);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte eliminado')));
      final nuevoFuture = _cargarReportes();
      setState(() { _future = nuevoFuture; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar reporte: $e')));
    }
  }



  Future<void> _abrirMapa(Map<String, dynamic> reporte) async {
    final lat = reporte['latitud']?.toString();
    final lng = reporte['longitud']?.toString();
    Uri uri;
    if (lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      final direccion = Uri.encodeComponent(reporte['direccion_incidente']?.toString() ?? '');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$direccion');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildEvidencia(Map<String, dynamic> reporte) {
    final url = reporte['evidencia_url']?.toString() ?? '';
    final tipo = reporte['tipo_evidencia']?.toString() ?? 'Archivo';
    if (url.isEmpty) return const SizedBox.shrink();
    if (tipo == 'Imagen') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AmpliableImage(
          url,
          height: 170,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('No se pudo cargar la imagen del reporte'),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.play_circle),
      label: Text('Abrir evidencia ($tipo)'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: GestionDirectivaScreen.primaryColor));
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final reportes = snapshot.data ?? [];
        if (reportes.isEmpty) return const Center(child: Text('No hay reportes registrados.'));

        return RefreshIndicator(
          onRefresh: () async {
            final nuevoFuture = _cargarReportes();
            setState(() {
              _future = nuevoFuture;
            });
            await nuevoFuture;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: reportes.length,
            itemBuilder: (context, index) {
              final r = reportes[index];
              final usuario = r['usuarios'] is Map
                  ? Map<String, dynamic>.from(r['usuarios'] as Map)
                  : <String, dynamic>{};
              final tipo = r['tipos_incidente'] is Map
                  ? Map<String, dynamic>.from(r['tipos_incidente'] as Map)
                  : <String, dynamic>{};
              final nombre = '${usuario['nombres'] ?? ''} ${usuario['apellidos'] ?? ''}'.trim();
              final estado = r['estado_reporte']?.toString() ?? 'Pendiente';
              final idReporte = r['id_reporte'] as int;
              final evidenciaUrl = r['evidencia_url']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment, color: GestionDirectivaScreen.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reporte #$idReporte - ${tipo['nombre_tipo'] ?? 'Sin tipo'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Eliminar reporte',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarReporte(idReporte),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Vecino: ${nombre.isEmpty ? r['dpi_usuario'] : nombre}'),
                      if (usuario['telefono'] != null) Text('Teléfono: ${usuario['telefono']}'),
                      InkWell(
                        onTap: () => _abrirMapa(r),
                        child: Text(
                          'Dirección: ${r['direccion_incidente'] ?? 'Sin dirección'}',
                          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                      Text('Descripción: ${r['descripcion'] ?? ''}'),
                      if (evidenciaUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildEvidencia(r),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _estados.contains(estado) ? estado : 'Pendiente',
                        decoration: const InputDecoration(
                          labelText: 'Estado del reporte',
                          border: OutlineInputBorder(),
                        ),
                        items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (value) {
                          if (value == null || value == estado) return;
                          _confirmarEstado(idReporte, value);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GestionProyectosTab extends StatefulWidget {
  const _GestionProyectosTab();

  @override
  State<_GestionProyectosTab> createState() => _GestionProyectosTabState();
}

class _GestionProyectosTabState extends State<_GestionProyectosTab> {
  late Future<List<Map<String, dynamic>>> _future;
  final List<String> _estados = const ['Planeación', 'En Ejecución', 'Finalizado'];

  @override
  void initState() {
    super.initState();
    _future = _cargarProyectos();
  }

  Future<List<Map<String, dynamic>>> _cargarProyectos() async {
    final data = await SupabaseService.client
        .from('proyectos')
        .select()
        .order('fecha_inicio', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? proyecto]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => _ProyectoFormDialog(proyecto: proyecto),
    );
    if (guardado == true) {
      final nuevoFuture = _cargarProyectos();
      setState(() {
        _future = nuevoFuture;
      });
    }
  }

  Future<void> _actualizarEstado(int idProyecto, String estado) async {
    try {
      await SupabaseService.client.from('proyectos').update({
        'estado': estado,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      }).eq('id_proyecto', idProyecto);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Proyecto actualizado a $estado')));
      final nuevoFuture = _cargarProyectos();
      setState(() {
        _future = nuevoFuture;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar proyecto: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GestionDirectivaScreen.primaryColor,
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Proyecto', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: GestionDirectivaScreen.primaryColor));
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final proyectos = snapshot.data ?? [];
          if (proyectos.isEmpty) return const Center(child: Text('No hay proyectos registrados.'));

          return RefreshIndicator(
            onRefresh: () async {
              final nuevoFuture = _cargarProyectos();
              setState(() {
                _future = nuevoFuture;
              });
              await nuevoFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: proyectos.length,
              itemBuilder: (context, index) {
                final p = proyectos[index];
                final estado = p['estado']?.toString() ?? 'Planeación';
                final id = p['id_proyecto'] as int;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((p['imagen_url']?.toString() ?? '').isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AmpliableImage(
                              p['imagen_url'].toString(),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                alignment: Alignment.center,
                                color: Colors.grey.shade300,
                                child: const Text('No se pudo cargar la imagen'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.handyman, color: GestionDirectivaScreen.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p['nombre_proyecto']?.toString() ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _abrirFormulario(p)),
                          ],
                        ),
                        Text(p['descripcion']?.toString() ?? ''),
                        const SizedBox(height: 8),
                        Text('Presupuesto: Q${p['presupuesto_aprox'] ?? '0'}'),
                        Text('Inicio: ${p['fecha_inicio'] ?? 'Sin fecha'}'),
                        Text('Finalización: ${p['fecha_finalizacion'] ?? 'Sin fecha'}'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _estados.contains(estado) ? estado : 'Planeación',
                          decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                          items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (value) {
                            if (value == null || value == estado) return;
                            _actualizarEstado(id, value);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProyectoFormDialog extends StatefulWidget {
  final Map<String, dynamic>? proyecto;
  const _ProyectoFormDialog({this.proyecto});

  @override
  State<_ProyectoFormDialog> createState() => _ProyectoFormDialogState();
}

class _ProyectoFormDialogState extends State<_ProyectoFormDialog> {
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _presupuesto = TextEditingController();
  final _fechaInicio = TextEditingController();
  final _fechaFinal = TextEditingController();
  String? _imagenUrl;
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  String _estado = 'Planeación';
  bool _loading = false;

  final List<String> _estados = const ['Planeación', 'En Ejecución', 'Finalizado'];

  @override
  void initState() {
    super.initState();
    final p = widget.proyecto;
    if (p != null) {
      _nombre.text = p['nombre_proyecto']?.toString() ?? '';
      _descripcion.text = p['descripcion']?.toString() ?? '';
      _presupuesto.text = p['presupuesto_aprox']?.toString() ?? '';
      _fechaInicio.text = p['fecha_inicio']?.toString() ?? '';
      _fechaFinal.text = p['fecha_finalizacion']?.toString() ?? '';
      _imagenUrl = p['imagen_url']?.toString();
      _estado = _estados.contains(p['estado']?.toString()) ? p['estado'].toString() : 'Planeación';
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _presupuesto.dispose();
    _fechaInicio.dispose();
    _fechaFinal.dispose();
    super.dispose();
  }


  Future<void> _seleccionarImagen() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _imagenBytes = file.bytes;
      _imagenNombre = file.name;
    });
  }

  Future<String?> _subirImagenSiExiste() async {
    if (_imagenBytes == null) return _imagenUrl;
    final ext = (_imagenNombre ?? 'proyecto.jpg').split('.').last;
    final fileName = 'proyecto_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await SupabaseService.client.storage.from('proyectos').uploadBinary(
      fileName,
      _imagenBytes!,
      fileOptions: const FileOptions(upsert: true),
    );
    return SupabaseService.client.storage.from('proyectos').getPublicUrl(fileName);
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresá el nombre del proyecto.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final data = {
        'nombre_proyecto': _nombre.text.trim(),
        'descripcion': _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
        'estado': _estado,
        'presupuesto_aprox': double.tryParse(_presupuesto.text.trim()),
        'fecha_inicio': _fechaInicio.text.trim().isEmpty ? null : _fechaInicio.text.trim(),
        'fecha_finalizacion': _fechaFinal.text.trim().isEmpty ? null : _fechaFinal.text.trim(),
        'imagen_url': await _subirImagenSiExiste(),
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      };

      if (widget.proyecto == null) {
        await SupabaseService.client.from('proyectos').insert(data);
      } else {
        await SupabaseService.client.from('proyectos').update(data).eq('id_proyecto', widget.proyecto!['id_proyecto']);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar proyecto: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seleccionarFecha(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) controller.text = picked.toIso8601String().split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.proyecto == null ? 'Crear proyecto' : 'Editar proyecto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: _descripcion, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción')),
            DropdownButtonFormField<String>(
              value: _estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => _estado = value ?? 'Planeación'),
            ),
            TextField(controller: _presupuesto, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Presupuesto aproximado')),
            TextField(controller: _fechaInicio, readOnly: true, onTap: () => _seleccionarFecha(_fechaInicio), decoration: const InputDecoration(labelText: 'Fecha inicio')),
            TextField(controller: _fechaFinal, readOnly: true, onTap: () => _seleccionarFecha(_fechaFinal), decoration: const InputDecoration(labelText: 'Fecha finalización')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _imagenBytes != null
                        ? 'Imagen seleccionada: ${_imagenNombre ?? ''}'
                        : ((_imagenUrl ?? '').isNotEmpty ? 'Imagen actual cargada' : 'Sin imagen'),
                  ),
                ),
                IconButton(
                  tooltip: 'Subir imagen',
                  onPressed: _seleccionarImagen,
                  icon: const Icon(Icons.upload_file, color: GestionDirectivaScreen.primaryColor),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _loading ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: GestionDirectivaScreen.primaryColor),
          child: Text(_loading ? 'Guardando...' : 'Guardar', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _GestionAnunciosTab extends StatefulWidget {
  const _GestionAnunciosTab();

  @override
  State<_GestionAnunciosTab> createState() => _GestionAnunciosTabState();
}

class _GestionAnunciosTabState extends State<_GestionAnunciosTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarAnuncios();
  }

  Future<List<Map<String, dynamic>>> _cargarAnuncios() async {
    final data = await SupabaseService.client
        .from('muro_noticias')
        .select()
        .eq('categoria_publicacion', 'Anuncio')
        .order('fecha_publicacion', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _eliminarAnuncio(Map<String, dynamic> anuncio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar anuncio'),
        content: Text('¿Eliminar "${anuncio['titulo'] ?? 'este anuncio'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await SupabaseService.client.from('muro_noticias').delete().eq('id_noticia', anuncio['id_noticia']);
    if (!mounted) return;
    final nuevoFuture = _cargarAnuncios();
    setState(() { _future = nuevoFuture; });
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? anuncio]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => _AnuncioFormDialog(anuncio: anuncio),
    );
    if (guardado == true) {
      final nuevoFuture = _cargarAnuncios();
      setState(() {
        _future = nuevoFuture;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GestionDirectivaScreen.primaryColor,
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Anuncio', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: GestionDirectivaScreen.primaryColor));
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final anuncios = snapshot.data ?? [];
          if (anuncios.isEmpty) return const Center(child: Text('No hay anuncios registrados.'));
          return RefreshIndicator(
            onRefresh: () async {
              final nuevoFuture = _cargarAnuncios();
              setState(() {
                _future = nuevoFuture;
              });
              await nuevoFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: anuncios.length,
              itemBuilder: (context, index) {
                final a = anuncios[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.campaign, color: GestionDirectivaScreen.primaryColor),
                    title: Text(a['titulo']?.toString() ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${a['tipo_noticia'] ?? 'Informativo'}\n${a['contenido'] ?? ''}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _abrirFormulario(a)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _eliminarAnuncio(a)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AnuncioFormDialog extends StatefulWidget {
  final Map<String, dynamic>? anuncio;
  const _AnuncioFormDialog({this.anuncio});

  @override
  State<_AnuncioFormDialog> createState() => _AnuncioFormDialogState();
}

class _AnuncioFormDialogState extends State<_AnuncioFormDialog> {
  final _titulo = TextEditingController();
  final _contenido = TextEditingController();
  String _tipo = 'Informativo';
  bool _loading = false;
  final List<String> _tipos = const ['Informativo', 'Alerta', 'Emergencia'];

  @override
  void initState() {
    super.initState();
    final a = widget.anuncio;
    if (a != null) {
      _titulo.text = a['titulo']?.toString() ?? '';
      _contenido.text = a['contenido']?.toString() ?? '';
      _tipo = _tipos.contains(a['tipo_noticia']?.toString()) ? a['tipo_noticia'].toString() : 'Informativo';
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _contenido.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_titulo.text.trim().isEmpty || _contenido.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completá título y contenido.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final data = {
        'titulo': _titulo.text.trim(),
        'contenido': _contenido.text.trim(),
        'tipo_noticia': _tipo,
        'fecha_publicacion': DateTime.now().toIso8601String(),
        'categoria_publicacion': 'Anuncio',
      };
      if (widget.anuncio == null) {
        await SupabaseService.client.from('muro_noticias').insert(data);
      } else {
        await SupabaseService.client.from('muro_noticias').update(data).eq('id_noticia', widget.anuncio!['id_noticia']);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar anuncio: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.anuncio == null ? 'Crear anuncio' : 'Editar anuncio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titulo, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: _contenido, maxLines: 4, decoration: const InputDecoration(labelText: 'Contenido')),
            DropdownButtonFormField<String>(
              value: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo de anuncio'),
              items: _tipos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => _tipo = value ?? 'Informativo'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _loading ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: GestionDirectivaScreen.primaryColor),
          child: Text(_loading ? 'Guardando...' : 'Guardar', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
