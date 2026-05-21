import 'package:flutter/material.dart';
import 'package:app_comunitaria/services/supabase_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _buscar = TextEditingController();
  final List<String> _roles = const ['Vecino', 'Directivo', 'Admin'];
  Future<List<Map<String, dynamic>>>? _futureUsuarios;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _buscarUsuarios() async {
    final q = _buscar.text.trim().toLowerCase();
    if (q.isEmpty) return [];

    // Más estable que usar .or() cuando hay RLS o caracteres como @ en el correo.
    final data = await SupabaseService.client
        .from('usuarios')
        .select('dpi, nombres, apellidos, correo, telefono, rol, foto_perfil_url')
        .order('nombres', ascending: true)
        .limit(300);

    final usuarios = List<Map<String, dynamic>>.from(data);
    return usuarios.where((u) {
      final texto = [
        u['dpi'],
        u['correo'],
        u['nombres'],
        u['apellidos'],
        u['telefono'],
      ].where((v) => v != null).join(' ').toLowerCase();
      return texto.contains(q);
    }).take(30).toList();
  }

  Future<DateTime?> _seleccionarFecha(DateTime? inicial) async {
    return showDatePicker(
      context: context,
      initialDate: inicial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
  }

  String _fechaSql(DateTime fecha) => fecha.toIso8601String().split('T').first;

  Future<Map<String, dynamic>?> _pedirDatosDirectiva(Map<String, dynamic> usuario) async {
    final nombre = '${usuario['nombres'] ?? ''} ${usuario['apellidos'] ?? ''}'.trim();
    final cargoCtrl = TextEditingController(text: 'Directivo');
    DateTime periodoInicio = DateTime.now();
    DateTime? periodoFin;

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Datos de directiva'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre.isEmpty ? 'DPI: ${usuario['dpi']}' : nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('DPI: ${usuario['dpi'] ?? ''}'),
                      Text('Teléfono: ${usuario['telefono'] ?? 'Sin teléfono'}'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: cargoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cargo en la directiva',
                          hintText: 'Presidente, Tesorero, Vocal...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.date_range),
                        title: const Text('Período inicio'),
                        subtitle: Text(_fechaSql(periodoInicio)),
                        onTap: () async {
                          final fecha = await _seleccionarFecha(periodoInicio);
                          if (fecha != null) setDialogState(() => periodoInicio = fecha);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available),
                        title: const Text('Período fin'),
                        subtitle: Text(periodoFin == null ? 'Sin definir' : _fechaSql(periodoFin!)),
                        onTap: () async {
                          final fecha = await _seleccionarFecha(periodoFin ?? periodoInicio);
                          if (fecha != null) setDialogState(() => periodoFin = fecha);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AdminScreen.primaryColor),
                    onPressed: () {
                      final cargo = cargoCtrl.text.trim();
                      if (cargo.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresá el cargo de la directiva.')));
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'cargo': cargo,
                        'periodo_inicio': _fechaSql(periodoInicio),
                        'periodo_fin': periodoFin == null ? null : _fechaSql(periodoFin!),
                        'imagen_url': usuario['foto_perfil_url'],
                      });
                    },
                    child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      cargoCtrl.dispose();
    }
  }

  Future<void> _sincronizarDirectiva(String dpi, String nuevoRol, {Map<String, dynamic>? datosDirectiva}) async {
    if (nuevoRol == 'Directivo') {
      final existe = await SupabaseService.client
          .from('directiva')
          .select('id_miembro')
          .eq('dpi_usuario', dpi)
          .order('id_miembro', ascending: false)
          .limit(1)
          .maybeSingle();

      final datos = {
        'dpi_usuario': dpi,
        'cargo': datosDirectiva?['cargo'] ?? 'Directivo',
        'periodo_inicio': datosDirectiva?['periodo_inicio'] ?? DateTime.now().toIso8601String().split('T').first,
        'periodo_fin': datosDirectiva?['periodo_fin'],
        'imagen_url': datosDirectiva?['imagen_url'],
      };

      if (existe == null) {
        await SupabaseService.client.from('directiva').insert(datos);
      } else {
        await SupabaseService.client
            .from('directiva')
            .update(datos)
            .eq('id_miembro', existe['id_miembro']);
      }
    } else {
      // Mantiene el historial en la tabla directiva, pero el usuario deja de aparecer
      // en la pestaña Directiva porque su rol actual ya no es Directivo.
      final hoy = DateTime.now().toIso8601String().split('T').first;
      await SupabaseService.client
          .from('directiva')
          .update({'periodo_fin': hoy})
          .eq('dpi_usuario', dpi)
          .filter('periodo_fin', 'is', null);
    }
  }

  Future<void> _actualizarRol(Map<String, dynamic> usuario, String nuevoRol) async {
    final dpi = usuario['dpi'].toString();
    try {
      Map<String, dynamic>? datosDirectiva;
      if (nuevoRol == 'Directivo') {
        datosDirectiva = await _pedirDatosDirectiva(usuario);
        if (datosDirectiva == null) return;
      }

      await SupabaseService.client.from('usuarios').update({'rol': nuevoRol}).eq('dpi', dpi);
      await _sincronizarDirectiva(dpi, nuevoRol, datosDirectiva: datosDirectiva);

      if (!mounted) return;
      final extra = AppSession.dpiUsuario == dpi ? ' Cerrá sesión y volvé a entrar para aplicar tu cambio de rol.' : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rol actualizado a $nuevoRol.$extra')));
      final nuevaBusqueda = _buscarUsuarios();
      setState(() { _futureUsuarios = nuevaBusqueda; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar rol: $e')));
    }
  }

  Future<void> _confirmarCambioRol(Map<String, dynamic> usuario, String nuevoRol) async {
    final nombre = '${usuario['nombres'] ?? ''} ${usuario['apellidos'] ?? ''}'.trim();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar rol'),
        content: Text('¿Cambiar el rol de ${nombre.isEmpty ? usuario['dpi'] : nombre} a $nuevoRol?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminScreen.primaryColor),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) await _actualizarRol(usuario, nuevoRol);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.esAdmin) {
      return const Scaffold(body: Center(child: Text('Acceso denegado. Solo administradores.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: AdminScreen.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Panel Admin'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscar,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por DPI, correo, nombre o apellido',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => setState(() { _futureUsuarios = _buscarUsuarios(); }),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() { _futureUsuarios = _buscarUsuarios(); }),
                  style: ElevatedButton.styleFrom(backgroundColor: AdminScreen.primaryColor),
                  child: const Text('Buscar', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _futureUsuarios == null
                ? const Center(child: Text('Buscá un usuario para cambiar su rol.'))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _futureUsuarios,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AdminScreen.primaryColor));
                      }
                      if (snapshot.hasError) return Center(child: Text('Error al buscar usuarios: ${snapshot.error}'));
                      final usuarios = snapshot.data ?? [];
                      if (usuarios.isEmpty) return const Center(child: Text('No se encontraron usuarios.'));

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: usuarios.length,
                        itemBuilder: (context, index) {
                          final usuario = usuarios[index];
                          final rolActual = (usuario['rol'] ?? 'Vecino').toString();
                          final nombre = '${usuario['nombres'] ?? ''} ${usuario['apellidos'] ?? ''}'.trim();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(backgroundColor: AdminScreen.primaryColor, child: Icon(Icons.person, color: Colors.white)),
                                    title: Text(nombre.isEmpty ? 'Sin nombre' : nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('DPI: ${usuario['dpi'] ?? ''}\nCorreo: ${usuario['correo'] ?? 'Sin correo'}'),
                                  ),
                                  DropdownButtonFormField<String>(
                                    value: _roles.contains(rolActual) ? rolActual : 'Vecino',
                                    decoration: const InputDecoration(labelText: 'Rol del usuario', border: OutlineInputBorder()),
                                    items: _roles.map((rol) => DropdownMenuItem(value: rol, child: Text(rol))).toList(),
                                    onChanged: (nuevoRol) {
                                      if (nuevoRol == null || nuevoRol == rolActual) return;
                                      _confirmarCambioRol(usuario, nuevoRol);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
