import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_app_comunitaria/services/supabase_service.dart';

class NegociosScreen extends StatefulWidget {
  const NegociosScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<NegociosScreen> createState() => _NegociosScreenState();
}

class _NegociosScreenState extends State<NegociosScreen> with SingleTickerProviderStateMixin {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: NegociosScreen.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Negocios locales'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.storefront), text: 'Catálogo'),
            Tab(icon: Icon(Icons.business_center), text: 'Mis negocios'),
            Tab(icon: Icon(Icons.local_offer), text: 'Promos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CatalogoNegociosTab(),
          _MisNegociosTab(),
          _PromocionesTab(),
        ],
      ),
    );
  }
}

class _CatalogoNegociosTab extends StatefulWidget {
  const _CatalogoNegociosTab();

  @override
  State<_CatalogoNegociosTab> createState() => _CatalogoNegociosTabState();
}

class _CatalogoNegociosTabState extends State<_CatalogoNegociosTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarNegocios();
  }

  Future<List<Map<String, dynamic>>> _cargarNegocios() async {
    final data = await SupabaseService.client
        .from('negocios')
        .select('id_negocio, nombre_comercial, dpi_propietario, ubicacion_referencia, telefono_contacto, imagen_url, latitud, longitud, fecha_registro, categorias_negocio(nombre_categoria), sectores_aldea(nombre_sector), usuarios(nombres, apellidos)')
        .order('nombre_comercial', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _abrirMapa(Map<String, dynamic> negocio) async {
    final lat = negocio['latitud']?.toString();
    final lng = negocio['longitud']?.toString();
    Uri uri;
    if (lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      final direccion = Uri.encodeComponent(negocio['ubicacion_referencia']?.toString() ?? '');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$direccion');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirWhatsapp(String telefono) async {
    final limpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final numero = limpio.startsWith('502') ? limpio : '502$limpio';
    final uri = Uri.parse('https://wa.me/$numero');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }


  Future<void> _eliminarNegocio(Map<String, dynamic> negocio) async {
    if (!AppSession.esDirectiva) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar negocio'),
        content: Text('¿Eliminar ${negocio['nombre_comercial'] ?? 'este negocio'}? También se eliminarán sus promociones.'),
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
      await SupabaseService.client.from('negocios').delete().eq('id_negocio', negocio['id_negocio']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Negocio eliminado')));
      final nuevoFuture = _cargarNegocios();
      setState(() { _future = nuevoFuture; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar negocio: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: NegociosScreen.primaryColor));
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final negocios = snapshot.data ?? [];
        if (negocios.isEmpty) return const Center(child: Text('Aún no hay negocios registrados.'));

        return RefreshIndicator(
          onRefresh: () async {
            final nuevoFuture = _cargarNegocios();
            setState(() { _future = nuevoFuture; });
            await nuevoFuture;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: negocios.length,
            itemBuilder: (context, index) {
              final n = negocios[index];
              final categoria = n['categorias_negocio'] is Map ? Map<String, dynamic>.from(n['categorias_negocio'] as Map) : <String, dynamic>{};
              final sector = n['sectores_aldea'] is Map ? Map<String, dynamic>.from(n['sectores_aldea'] as Map) : <String, dynamic>{};
              final propietario = n['usuarios'] is Map ? Map<String, dynamic>.from(n['usuarios'] as Map) : <String, dynamic>{};
              final imagen = n['imagen_url']?.toString() ?? '';
              final telefono = n['telefono_contacto']?.toString() ?? '';
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
                          child: Image.network(
                            imagen,
                            height: 170,
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
                          const Icon(Icons.storefront, color: NegociosScreen.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              n['nombre_comercial']?.toString() ?? 'Sin nombre',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          if (AppSession.esDirectiva)
                            IconButton(
                              tooltip: 'Eliminar negocio',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _eliminarNegocio(n),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Categoría: ${categoria['nombre_categoria'] ?? 'Sin categoría'}'),
                      Text('Sector/Aldea: ${sector['nombre_sector'] ?? 'Sin sector'}'),
                      Text('Propietario: ${propietario['nombres'] ?? ''} ${propietario['apellidos'] ?? ''}'.trim()),
                      if (telefono.isNotEmpty) Text('Teléfono: $telefono'),
                      InkWell(
                        onTap: () => _abrirMapa(n),
                        child: Text(
                          'Dirección: ${n['ubicacion_referencia'] ?? 'Sin dirección'}',
                          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _abrirMapa(n),
                              icon: const Icon(Icons.map),
                              label: const Text('Google Maps'),
                            ),
                          ),
                          if (telefono.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: NegociosScreen.primaryColor),
                                onPressed: () => _abrirWhatsapp(telefono),
                                icon: const Icon(Icons.chat, color: Colors.white),
                                label: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ],
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

class _MisNegociosTab extends StatefulWidget {
  const _MisNegociosTab();

  @override
  State<_MisNegociosTab> createState() => _MisNegociosTabState();
}

class _MisNegociosTabState extends State<_MisNegociosTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarMisNegocios();
  }

  Future<List<Map<String, dynamic>>> _cargarMisNegocios() async {
    final dpi = AppSession.dpiUsuario;
    if (dpi == null) return [];
    final data = await SupabaseService.client
        .from('negocios')
        .select('id_negocio, nombre_comercial, dpi_propietario, ubicacion_referencia, telefono_contacto, imagen_url, latitud, longitud, id_categoria, id_sector, categorias_negocio(nombre_categoria), sectores_aldea(nombre_sector)')
        .eq('dpi_propietario', dpi)
        .order('nombre_comercial', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? negocio]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _NegocioFormDialog(negocio: negocio),
    );
    if (guardado == true) {
      final nuevoFuture = _cargarMisNegocios();
      setState(() { _future = nuevoFuture; });
    }
  }

  Future<void> _eliminarNegocio(Map<String, dynamic> negocio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar negocio'),
        content: Text('¿Eliminar ${negocio['nombre_comercial']}? También se eliminarán sus promociones.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    await SupabaseService.client.from('negocios').delete().eq('id_negocio', negocio['id_negocio']);
    final nuevoFuture = _cargarMisNegocios();
    if (mounted) setState(() { _future = nuevoFuture; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NegociosScreen.primaryColor,
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Negocio', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: NegociosScreen.primaryColor));
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final negocios = snapshot.data ?? [];
          if (negocios.isEmpty) {
            return const Center(child: Text('No tenés negocios registrados. Tocá + para registrar uno.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              final nuevoFuture = _cargarMisNegocios();
              setState(() { _future = nuevoFuture; });
              await nuevoFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: negocios.length,
              itemBuilder: (context, index) {
                final n = negocios[index];
                final categoria = n['categorias_negocio'] is Map ? Map<String, dynamic>.from(n['categorias_negocio'] as Map) : <String, dynamic>{};
                final sector = n['sectores_aldea'] is Map ? Map<String, dynamic>.from(n['sectores_aldea'] as Map) : <String, dynamic>{};
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.storefront, color: NegociosScreen.primaryColor),
                    title: Text(n['nombre_comercial']?.toString() ?? 'Sin nombre'),
                    subtitle: Text('${categoria['nombre_categoria'] ?? 'Sin categoría'} • ${sector['nombre_sector'] ?? 'Sin sector'}'),
                    trailing: Wrap(
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _abrirFormulario(n)),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () => _eliminarNegocio(n)),
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

class _NegocioFormDialog extends StatefulWidget {
  final Map<String, dynamic>? negocio;
  const _NegocioFormDialog({this.negocio});

  @override
  State<_NegocioFormDialog> createState() => _NegocioFormDialogState();
}

class _NegocioFormDialogState extends State<_NegocioFormDialog> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  Uint8List? _imagenBytes;
  String? _imagenNombre;
  String? _imagenUrl;
  double? _latitud;
  double? _longitud;
  int? _idCategoria;
  int? _idSector;
  bool _loading = false;
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _sectores = [];

  @override
  void initState() {
    super.initState();
    final n = widget.negocio;
    if (n != null) {
      _nombre.text = n['nombre_comercial']?.toString() ?? '';
      _telefono.text = (n['telefono_contacto']?.toString() ?? '').replaceFirst('+502', '');
      _direccion.text = n['ubicacion_referencia']?.toString() ?? '';
      _imagenUrl = n['imagen_url']?.toString();
      _latitud = double.tryParse(n['latitud']?.toString() ?? '');
      _longitud = double.tryParse(n['longitud']?.toString() ?? '');
      _idCategoria = int.tryParse(n['id_categoria']?.toString() ?? '');
      _idSector = int.tryParse(n['id_sector']?.toString() ?? '');
    }
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    final categorias = await SupabaseService.client.from('categorias_negocio').select().order('nombre_categoria');
    final sectores = await SupabaseService.client.from('sectores_aldea').select().order('nombre_sector');
    if (!mounted) return;
    setState(() {
      _categorias = List<Map<String, dynamic>>.from(categorias);
      _sectores = List<Map<String, dynamic>>.from(sectores);
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
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
    final ext = (_imagenNombre ?? 'negocio.jpg').split('.').last;
    final fileName = '${AppSession.dpiUsuario ?? 'usuario'}/negocio_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await SupabaseService.client.storage.from('negocios').uploadBinary(
      fileName,
      _imagenBytes!,
      fileOptions: const FileOptions(upsert: true),
    );
    return SupabaseService.client.storage.from('negocios').getPublicUrl(fileName);
  }

  Future<void> _usarUbicacionActual() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso de ubicación denegado.')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final marcas = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = marcas.isNotEmpty ? marcas.first : null;
      final direccion = p == null
          ? '${pos.latitude}, ${pos.longitude}'
          : [p.street, p.locality, p.administrativeArea, p.country].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
      setState(() {
        _latitud = pos.latitude;
        _longitud = pos.longitude;
        _direccion.text = direccion;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener ubicación: $e')));
    }
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty || _idCategoria == null || _idSector == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completá nombre, categoría y sector.')));
      return;
    }
    final dpi = AppSession.dpiUsuario;
    if (dpi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró tu DPI de sesión.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final tel = _telefono.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final data = {
        'nombre_comercial': _nombre.text.trim(),
        'dpi_propietario': dpi,
        'id_categoria': _idCategoria,
        'id_sector': _idSector,
        'ubicacion_referencia': _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
        'telefono_contacto': tel.isEmpty ? null : '+502$tel',
        'latitud': _latitud,
        'longitud': _longitud,
        'imagen_url': await _subirImagenSiExiste(),
      };
      if (widget.negocio == null) {
        await SupabaseService.client.from('negocios').insert(data);
      } else {
        await SupabaseService.client.from('negocios').update(data).eq('id_negocio', widget.negocio!['id_negocio']);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar negocio: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.negocio == null ? 'Registrar negocio' : 'Editar negocio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre comercial')),
            TextField(controller: _telefono, keyboardType: TextInputType.phone, maxLength: 8, decoration: const InputDecoration(prefixText: '+502 ', labelText: 'Teléfono')),
            DropdownButtonFormField<int>(
              value: _idCategoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categorias.map((c) => DropdownMenuItem(value: c['id_categoria'] as int, child: Text(c['nombre_categoria'].toString()))).toList(),
              onChanged: (value) => setState(() => _idCategoria = value),
            ),
            DropdownButtonFormField<int>(
              value: _idSector,
              decoration: const InputDecoration(labelText: 'Sector/Aldea'),
              items: _sectores.map((s) => DropdownMenuItem(value: s['id_sector'] as int, child: Text(s['nombre_sector'].toString()))).toList(),
              onChanged: (value) => setState(() => _idSector = value),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: NegociosScreen.primaryColor),
              onPressed: _usarUbicacionActual,
              icon: const Icon(Icons.my_location, color: Colors.white),
              label: const Text('Usar dirección actual', style: TextStyle(color: Colors.white)),
            ),
            TextField(controller: _direccion, maxLines: 2, decoration: const InputDecoration(labelText: 'Dirección del negocio')),
            if (_latitud != null && _longitud != null)
              Text('GPS: ${_latitud!.toStringAsFixed(6)}, ${_longitud!.toStringAsFixed(6)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(_imagenBytes != null ? 'Imagen seleccionada: ${_imagenNombre ?? ''}' : ((_imagenUrl ?? '').isNotEmpty ? 'Imagen actual cargada' : 'Sin imagen de fachada')),
                ),
                IconButton(
                  tooltip: 'Subir fachada',
                  onPressed: _seleccionarImagen,
                  icon: const Icon(Icons.upload_file, color: NegociosScreen.primaryColor),
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
          style: ElevatedButton.styleFrom(backgroundColor: NegociosScreen.primaryColor),
          child: Text(_loading ? 'Guardando...' : 'Guardar', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _PromocionesTab extends StatefulWidget {
  const _PromocionesTab();

  @override
  State<_PromocionesTab> createState() => _PromocionesTabState();
}

class _PromocionesTabState extends State<_PromocionesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarPromociones();
  }

  Future<List<Map<String, dynamic>>> _cargarPromociones() async {
    final data = await SupabaseService.client
        .from('promociones')
        .select('id_promo, id_negocio, titulo_oferta, descripcion_oferta, fecha_inicio, validez_hasta, negocios(nombre_comercial, telefono_contacto, ubicacion_referencia, latitud, longitud, imagen_url, sectores_aldea(nombre_sector))')
        .order('fecha_inicio', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> _cargarMisNegocios() async {
    final dpi = AppSession.dpiUsuario;
    if (dpi == null) return [];
    final data = await SupabaseService.client
        .from('negocios')
        .select('id_negocio, nombre_comercial')
        .eq('dpi_propietario', dpi)
        .order('nombre_comercial');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _abrirFormulario() async {
    final negocios = await _cargarMisNegocios();
    if (!mounted) return;
    if (negocios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero registrá un negocio.')));
      return;
    }
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _PromocionFormDialog(negocios: negocios),
    );
    if (guardado == true) {
      final nuevoFuture = _cargarPromociones();
      setState(() { _future = nuevoFuture; });
    }
  }

  Future<void> _abrirMapa(Map<String, dynamic> negocio) async {
    final lat = negocio['latitud']?.toString();
    final lng = negocio['longitud']?.toString();
    Uri uri;
    if (lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      final direccion = Uri.encodeComponent(negocio['ubicacion_referencia']?.toString() ?? '');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$direccion');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }


  Future<void> _eliminarPromocion(Map<String, dynamic> promo) async {
    if (!AppSession.esDirectiva) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar promoción'),
        content: Text('¿Eliminar ${promo['titulo_oferta'] ?? 'esta promoción'}?'),
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
      await SupabaseService.client.from('promociones').delete().eq('id_promo', promo['id_promo']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promoción eliminada')));
      final nuevoFuture = _cargarPromociones();
      setState(() { _future = nuevoFuture; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar promoción: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NegociosScreen.primaryColor,
        onPressed: _abrirFormulario,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Promoción', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: NegociosScreen.primaryColor));
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final promos = snapshot.data ?? [];
          if (promos.isEmpty) return const Center(child: Text('Aún no hay promociones publicadas.'));
          return RefreshIndicator(
            onRefresh: () async {
              final nuevoFuture = _cargarPromociones();
              setState(() { _future = nuevoFuture; });
              await nuevoFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: promos.length,
              itemBuilder: (context, index) {
                final p = promos[index];
                final negocio = p['negocios'] is Map ? Map<String, dynamic>.from(p['negocios'] as Map) : <String, dynamic>{};
                final sector = negocio['sectores_aldea'] is Map ? Map<String, dynamic>.from(negocio['sectores_aldea'] as Map) : <String, dynamic>{};
                final imagen = negocio['imagen_url']?.toString() ?? '';
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
                            child: Image.network(imagen, height: 150, width: double.infinity, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.local_offer, color: NegociosScreen.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p['titulo_oferta']?.toString() ?? 'Promoción', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                            if (AppSession.esDirectiva)
                              IconButton(
                                tooltip: 'Eliminar promoción',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarPromocion(p),
                              ),
                          ],
                        ),
                        Text('Negocio: ${negocio['nombre_comercial'] ?? 'Sin negocio'}'),
                        Text('Sector/Aldea: ${sector['nombre_sector'] ?? 'Sin sector'}'),
                        const SizedBox(height: 6),
                        Text(p['descripcion_oferta']?.toString() ?? ''),
                        Text('Válido: ${p['fecha_inicio'] ?? ''} - ${p['validez_hasta'] ?? ''}'),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _abrirMapa(negocio),
                          icon: const Icon(Icons.map),
                          label: const Text('Ver ubicación en Google Maps'),
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

class _PromocionFormDialog extends StatefulWidget {
  final List<Map<String, dynamic>> negocios;
  const _PromocionFormDialog({required this.negocios});

  @override
  State<_PromocionFormDialog> createState() => _PromocionFormDialogState();
}

class _PromocionFormDialogState extends State<_PromocionFormDialog> {
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _fechaInicio = TextEditingController();
  final _fechaFin = TextEditingController();
  int? _idNegocio;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _idNegocio = widget.negocios.first['id_negocio'] as int;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _fechaInicio.dispose();
    _fechaFin.dispose();
    super.dispose();
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

  Future<void> _guardar() async {
    if (_titulo.text.trim().isEmpty || _fechaInicio.text.trim().isEmpty || _fechaFin.text.trim().isEmpty || _idNegocio == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completá título, negocio y fechas.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('promociones').insert({
        'id_negocio': _idNegocio,
        'titulo_oferta': _titulo.text.trim(),
        'descripcion_oferta': _descripcion.text.trim(),
        'fecha_inicio': _fechaInicio.text.trim(),
        'validez_hasta': _fechaFin.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar promoción: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear promoción'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _idNegocio,
              decoration: const InputDecoration(labelText: 'Negocio'),
              items: widget.negocios.map((n) => DropdownMenuItem(value: n['id_negocio'] as int, child: Text(n['nombre_comercial'].toString()))).toList(),
              onChanged: (value) => setState(() => _idNegocio = value),
            ),
            TextField(controller: _titulo, decoration: const InputDecoration(labelText: 'Título de la oferta')),
            TextField(controller: _descripcion, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción')),
            TextField(controller: _fechaInicio, readOnly: true, onTap: () => _seleccionarFecha(_fechaInicio), decoration: const InputDecoration(labelText: 'Fecha inicio')),
            TextField(controller: _fechaFin, readOnly: true, onTap: () => _seleccionarFecha(_fechaFin), decoration: const InputDecoration(labelText: 'Válido hasta')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _loading ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: NegociosScreen.primaryColor),
          child: Text(_loading ? 'Guardando...' : 'Guardar', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
