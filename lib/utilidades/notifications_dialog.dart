import 'package:flutter/material.dart';
import 'package:app_comunitaria/services/supabase_service.dart';

class NotificationsDialog extends StatelessWidget {
  const NotificationsDialog({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => const NotificationsDialog(),
    );
  }

  Future<List<Map<String, dynamic>>> _cargarNotificaciones() async {
    final List<Map<String, dynamic>> notificaciones = [];

    // Anuncios oficiales para todos los usuarios: Informativo, Alerta y Emergencia.
    final noticias = await SupabaseService.client
        .from('muro_noticias')
        .select('id_noticia, titulo, contenido, tipo_noticia, fecha_publicacion')
        .eq('categoria_publicacion', 'Anuncio')
        .order('fecha_publicacion', ascending: false)
        .limit(10);

    for (final noticia in List<Map<String, dynamic>>.from(noticias)) {
      final tipo = noticia['tipo_noticia']?.toString() ?? 'Informativo';
      IconData icono = Icons.info;
      String titulo = 'Anuncio oficial';
      if (tipo == 'Alerta') {
        icono = Icons.warning;
        titulo = 'Alerta comunitaria';
      } else if (tipo == 'Emergencia') {
        icono = Icons.emergency;
        titulo = 'Emergencia comunitaria';
      }
      notificaciones.add({
        'titulo': titulo,
        'mensaje': '${noticia['titulo'] ?? 'Sin título'}\n${noticia['contenido'] ?? ''}',
        'fecha': noticia['fecha_publicacion'],
        'icono': icono,
      });
    }

    // Proyectos visibles para todos en la campanita general.
    final proyectos = await SupabaseService.client
        .from('proyectos')
        .select('id_proyecto, nombre_proyecto, descripcion, estado, fecha_inicio, fecha_actualizacion')
        .order('fecha_actualizacion', ascending: false)
        .limit(10);

    for (final proyecto in List<Map<String, dynamic>>.from(proyectos)) {
      notificaciones.add({
        'titulo': 'Proyecto comunitario: ${proyecto['estado'] ?? 'Sin estado'}',
        'mensaje': '${proyecto['nombre_proyecto'] ?? 'Sin nombre'}\n${proyecto['descripcion'] ?? ''}',
        'fecha': proyecto['fecha_actualizacion'] ?? proyecto['fecha_inicio'],
        'icono': Icons.handyman,
      });
    }

    // Actualizaciones de reportes: solo para el usuario que creó el reporte.
    if (AppSession.dpiUsuario != null) {
      final reportes = await SupabaseService.client
          .from('reportes')
          .select('id_reporte, estado_reporte, descripcion, fecha_reporte, fecha_actualizacion')
          .eq('dpi_usuario', AppSession.dpiUsuario!)
          .order('fecha_actualizacion', ascending: false)
          .limit(10);

      for (final reporte in List<Map<String, dynamic>>.from(reportes)) {
        final estado = reporte['estado_reporte']?.toString() ?? 'Pendiente';
        notificaciones.add({
          'titulo': 'Tu reporte #${reporte['id_reporte']} está: $estado',
          'mensaje': reporte['descripcion']?.toString() ?? 'Tu reporte fue actualizado.',
          'fecha': reporte['fecha_actualizacion'] ?? reporte['fecha_reporte'],
          'icono': Icons.description,
        });
      }
    }

    notificaciones.sort((a, b) {
      final fa = DateTime.tryParse(a['fecha']?.toString() ?? '') ?? DateTime(1900);
      final fb = DateTime.tryParse(b['fecha']?.toString() ?? '') ?? DateTime(1900);
      return fb.compareTo(fa);
    });

    return notificaciones.take(20).toList();
  }

  String _formatearFecha(dynamic fecha) {
    final parsed = DateTime.tryParse(fecha?.toString() ?? '');
    if (parsed == null) return 'Reciente';
    final date = parsed.toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 0) {
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      return '$d/$m/${date.year}';
    }
    if (diff.inMinutes >= 0 && diff.inMinutes < 2) return 'Ahora';
    if (diff.inMinutes >= 0 && diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours >= 0 && diff.inHours < 24) return '${diff.inHours} h';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/${date.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2).withOpacity(0.97),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  const Expanded(
                    child: Text('Notificaciones', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _cargarNotificaciones(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error al cargar notificaciones: ${snapshot.error}'),
                    );
                  }

                  final notificaciones = snapshot.data ?? [];
                  if (notificaciones.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('No hay notificaciones por ahora.'),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: notificaciones.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = notificaciones[index];
                      return _buildNotificationCard(
                        item['titulo']?.toString() ?? 'Notificación',
                        item['mensaje']?.toString() ?? '',
                        _formatearFecha(item['fecha']),
                        item['icono'] as IconData? ?? Icons.notifications,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(String titulo, String mensaje, String tiempo, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 8),
          Text(mensaje, style: const TextStyle(color: Colors.black87, fontSize: 12, height: 1.3)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.access_time, color: primaryColor, size: 12),
              const SizedBox(width: 4),
              Text(tiempo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
