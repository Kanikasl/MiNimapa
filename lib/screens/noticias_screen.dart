import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:app_comunitaria/widgets/ampliable_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app_comunitaria/services/supabase_service.dart';

class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarNoticias();
  }

  Future<List<Map<String, dynamic>>> _cargarNoticias() async {
    final data = await SupabaseService.client
        .from('muro_noticias')
        .select('id_noticia, titulo, contenido, tipo_noticia, imagen_url, fecha_publicacion, dpi_autor, usuarios(nombres, apellidos)')
        .eq('categoria_publicacion', 'Noticia')
        .order('fecha_publicacion', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _abrirFormulario() async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => const _NoticiaFormDialog(),
    );
    if (guardado == true) {
      final nuevoFuture = _cargarNoticias();
      setState(() { _future = nuevoFuture; });
    }
  }

  Future<void> _eliminarNoticia(Map<String, dynamic> noticia) async {
    if (!AppSession.esDirectiva) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content: Text('¿Eliminar "${noticia['titulo'] ?? 'esta noticia'}"?'),
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
      await SupabaseService.client.from('muro_noticias').delete().eq('id_noticia', noticia['id_noticia']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Noticia eliminada')));
      final nuevoFuture = _cargarNoticias();
      setState(() { _future = nuevoFuture; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar noticia: $e')));
    }
  }

  IconData _iconoTipo(String tipo) {
    if (tipo == 'Alerta') return Icons.warning;
    if (tipo == 'Emergencia') return Icons.emergency;
    return Icons.info;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: NoticiasScreen.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Noticias comunitarias'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NoticiasScreen.primaryColor,
        onPressed: _abrirFormulario,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Noticia', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: NoticiasScreen.primaryColor));
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final noticias = snapshot.data ?? [];
          if (noticias.isEmpty) return const Center(child: Text('Aún no hay noticias publicadas.'));

          return RefreshIndicator(
            onRefresh: () async {
              final nuevoFuture = _cargarNoticias();
              setState(() { _future = nuevoFuture; });
              await nuevoFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: noticias.length,
              itemBuilder: (context, index) {
                final n = noticias[index];
                final tipo = n['tipo_noticia']?.toString() ?? 'Informativo';
                final imagen = n['imagen_url']?.toString() ?? '';
                final autor = n['usuarios'] is Map ? Map<String, dynamic>.from(n['usuarios'] as Map) : <String, dynamic>{};
                final nombreAutor = '${autor['nombres'] ?? ''} ${autor['apellidos'] ?? ''}'.trim();

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imagen.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AmpliableImage(
                              imagen,
                              height: 180,
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
                            Icon(_iconoTipo(tipo), color: NoticiasScreen.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                n['titulo']?.toString() ?? 'Sin título',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            if (AppSession.esDirectiva)
                              IconButton(
                                tooltip: 'Eliminar noticia',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarNoticia(n),
                              ),
                          ],
                        ),
                        Text(tipo, style: const TextStyle(color: NoticiasScreen.primaryColor, fontWeight: FontWeight.bold)),
                        if (nombreAutor.isNotEmpty) Text('Publicado por: $nombreAutor'),
                        const SizedBox(height: 8),
                        Text(n['contenido']?.toString() ?? ''),
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

class _NoticiaFormDialog extends StatefulWidget {
  const _NoticiaFormDialog();

  @override
  State<_NoticiaFormDialog> createState() => _NoticiaFormDialogState();
}

class _NoticiaFormDialogState extends State<_NoticiaFormDialog> {
  final _titulo = TextEditingController();
  final _contenido = TextEditingController();
  String _tipo = 'Informativo';
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  bool _loading = false;
  final List<String> _tipos = const ['Informativo', 'Alerta', 'Emergencia'];

  @override
  void dispose() {
    _titulo.dispose();
    _contenido.dispose();
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
    if (_imagenBytes == null) return null;
    final ext = (_imagenNombre ?? 'noticia.jpg').split('.').last;
    final fileName = 'noticia_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await SupabaseService.client.storage.from('noticias').uploadBinary(
      fileName,
      _imagenBytes!,
      fileOptions: const FileOptions(upsert: true),
    );
    return SupabaseService.client.storage.from('noticias').getPublicUrl(fileName);
  }

  Future<void> _guardar() async {
    if (_titulo.text.trim().isEmpty || _contenido.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completá título y contenido.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final imagenUrl = await _subirImagenSiExiste();
      await SupabaseService.client.from('muro_noticias').insert({
        'categoria_publicacion': 'Noticia',
        'titulo': _titulo.text.trim(),
        'contenido': _contenido.text.trim(),
        'tipo_noticia': _tipo,
        'imagen_url': imagenUrl,
        'dpi_autor': AppSession.dpiUsuario,
        'fecha_publicacion': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al publicar noticia: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear noticia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titulo, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: _contenido, maxLines: 4, decoration: const InputDecoration(labelText: 'Contenido')),
            DropdownButtonFormField<String>(
              value: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: _tipos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => _tipo = value ?? 'Informativo'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_imagenBytes == null ? 'Imagen opcional' : 'Imagen seleccionada: ${_imagenNombre ?? ''}'),
                ),
                IconButton(
                  tooltip: 'Subir imagen',
                  onPressed: _seleccionarImagen,
                  icon: const Icon(Icons.upload_file, color: NoticiasScreen.primaryColor),
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
          style: ElevatedButton.styleFrom(backgroundColor: NoticiasScreen.primaryColor),
          child: Text(_loading ? 'Publicando...' : 'Publicar', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
