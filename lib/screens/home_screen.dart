import 'package:flutter/material.dart';
import 'package:flutter_app_comunitaria/screens/admin_screen.dart';
import 'package:flutter_app_comunitaria/screens/directiva_screen.dart';
import 'package:flutter_app_comunitaria/screens/gestion_directiva_screen.dart';
import 'package:flutter_app_comunitaria/screens/login_screen.dart';
import 'package:flutter_app_comunitaria/screens/negocios_screen.dart';
import 'package:flutter_app_comunitaria/screens/noticias_screen.dart';
import 'package:flutter_app_comunitaria/screens/profile_screen.dart';
import 'package:flutter_app_comunitaria/screens/proyecto_screen.dart';
import 'package:flutter_app_comunitaria/screens/reporte_screen.dart';
import 'package:flutter_app_comunitaria/services/supabase_service.dart';
import 'package:flutter_app_comunitaria/utilidades/notifications_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primaryColor = HomeScreen.primaryColor;
  late Future<Map<String, List<Map<String, dynamic>>>> _futureInicio;

  @override
  void initState() {
    super.initState();
    _futureInicio = _cargarInicio();
  }

  Future<void> _refrescarInicio() async {
    final nuevoFuture = _cargarInicio();
    setState(() => _futureInicio = nuevoFuture);
    await nuevoFuture;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _cargarInicio() async {
    final anunciosData = await SupabaseService.client
        .from('muro_noticias')
        .select()
        .eq('categoria_publicacion', 'Anuncio')
        .order('fecha_publicacion', ascending: false);

    final noticiasData = await SupabaseService.client
        .from('muro_noticias')
        .select()
        .eq('categoria_publicacion', 'Noticia')
        .order('fecha_publicacion', ascending: false);

    final reportesData = await SupabaseService.client
        .from('reportes')
        .select('id_reporte, dpi_usuario, descripcion, direccion_incidente, latitud, longitud, evidencia_url, tipo_evidencia, estado_reporte, fecha_reporte, tipos_incidente(nombre_tipo), usuarios(nombres, apellidos, telefono)')
        .order('fecha_reporte', ascending: false)
        .limit(20);

    return {
      'anuncios': List<Map<String, dynamic>>.from(anunciosData),
      'noticias': List<Map<String, dynamic>>.from(noticiasData),
      'reportes': List<Map<String, dynamic>>.from(reportesData),
    };
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      bottomNavigationBar: _buildBottomNavigation(context),
      body: Column(
        children: [
          _buildHeader(context),
          if (AppSession.esDirectiva) _buildRoleBanner(),
          Expanded(
            child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
              future: _futureInicio,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar inicio: ${snapshot.error}'));
                }

                final anuncios = snapshot.data?['anuncios'] ?? [];
                final noticias = snapshot.data?['noticias'] ?? [];
                final reportes = snapshot.data?['reportes'] ?? [];

                if (anuncios.isEmpty && noticias.isEmpty && reportes.isEmpty) {
                  return const Center(child: Text('Aún no hay publicaciones ni reportes registrados.'));
                }

                return RefreshIndicator(
                  onRefresh: _refrescarInicio,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (anuncios.isNotEmpty) ...[
                        const Text('Anuncios oficiales y emergencias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                        const SizedBox(height: 8),
                        ...anuncios.map((noticia) => _buildNewsCard(
                              noticia['titulo']?.toString() ?? 'Sin título',
                              noticia['contenido']?.toString() ?? '',
                              noticia['tipo_noticia']?.toString() ?? 'Informativo',
                              noticia['imagen_url']?.toString(),
                            )),
                      ],
                      if (noticias.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Noticias comunitarias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                        const SizedBox(height: 8),
                        ...noticias.map((noticia) => _buildNewsCard(
                              noticia['titulo']?.toString() ?? 'Sin título',
                              noticia['contenido']?.toString() ?? '',
                              noticia['tipo_noticia']?.toString() ?? 'Informativo',
                              noticia['imagen_url']?.toString(),
                            )),
                      ],
                      if (reportes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Reportes comunitarios recientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                        const SizedBox(height: 8),
                        ...reportes.map((reporte) => _buildReporteCard(reporte)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
      const BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Directiva'),
      const BottomNavigationBarItem(icon: Icon(Icons.handyman), label: 'Proyectos'),
      const BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Negocios'),
      const BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Noticias'),
      const BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Reportes'),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      if (AppSession.esDirectiva) const BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Gestión'),
      if (AppSession.esAdmin) const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
    ];

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      currentIndex: 0,
      onTap: (index) {
        if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const DirectivaScreen())).then((_) => _refrescarInicio());
        } else if (index == 2) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProyectoScreen())).then((_) => _refrescarInicio());
        } else if (index == 3) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const NegociosScreen())).then((_) => _refrescarInicio());
        } else if (index == 4) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const NoticiasScreen())).then((_) => _refrescarInicio());
        } else if (index == 5) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ReporteScreen())).then((_) => _refrescarInicio());
        } else if (index == 6) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _refrescarInicio());
        } else if (AppSession.esDirectiva && index == 7) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const GestionDirectivaScreen())).then((_) => _refrescarInicio());
        } else if (AppSession.esAdmin && index == (AppSession.esDirectiva ? 8 : 7)) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen())).then((_) => _refrescarInicio());
        }
      },
      items: items,
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
          Image.asset('assets/nimapa_logotipo.png', height: 55),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('MiNimapa', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () => NotificationsDialog.show(context),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Seguro que querés cerrar sesión?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );

              if (confirmar != true) return;
              await AppSession.cerrarSesion();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBanner() {
    final rol = AppSession.rolUsuario ?? '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rol == 'Admin' ? 'Modo administrador activo' : 'Modo directiva activo',
              style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(String title, String content, String type, String? imageUrl) {
    IconData icon = Icons.info;
    if (type == 'Alerta') icon = Icons.warning;
    if (type == 'Emergencia') icon = Icons.emergency;

    final tieneImagen = imageUrl != null && imageUrl.trim().isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 6),
            Text(type, style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(content),
            if (tieneImagen) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 120, alignment: Alignment.center, color: Colors.grey.shade300, child: const Text('No se pudo cargar la imagen')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReporteCard(Map<String, dynamic> reporte) {
    final tipo = reporte['tipos_incidente'] is Map ? Map<String, dynamic>.from(reporte['tipos_incidente'] as Map) : <String, dynamic>{};
    final usuario = reporte['usuarios'] is Map ? Map<String, dynamic>.from(reporte['usuarios'] as Map) : <String, dynamic>{};
    final nombre = '${usuario['nombres'] ?? ''} ${usuario['apellidos'] ?? ''}'.trim();
    final evidencia = reporte['evidencia_url']?.toString() ?? '';
    final tipoEvidencia = reporte['tipo_evidencia']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text('Reporte #${reporte['id_reporte']} - ${tipo['nombre_tipo'] ?? 'Sin tipo'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 6),
            Text('Estado: ${reporte['estado_reporte'] ?? 'Pendiente'}', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            Text('Vecino: ${nombre.isEmpty ? reporte['dpi_usuario'] : nombre}'),
            Text('Descripción: ${reporte['descripcion'] ?? ''}'),
            InkWell(
              onTap: () => _abrirMapa(reporte),
              child: Text('Dirección: ${reporte['direccion_incidente'] ?? 'Sin dirección'}', style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
            ),
            if (evidencia.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (tipoEvidencia == 'Imagen')
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(evidencia, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 120, alignment: Alignment.center, color: Colors.grey.shade300, child: const Text('No se pudo cargar la imagen'))),
                )
              else
                OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(evidencia), mode: LaunchMode.externalApplication), icon: const Icon(Icons.play_circle), label: const Text('Abrir video/evidencia')),
            ],
          ],
        ),
      ),
    );
  }
}
