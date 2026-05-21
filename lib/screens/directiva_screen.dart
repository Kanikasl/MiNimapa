import 'package:flutter/material.dart';
import 'package:flutter_app_comunitaria/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DirectivaScreen extends StatelessWidget {
  const DirectivaScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  Future<List<Map<String, dynamic>>> _cargarDirectiva() async {
    // 1) Carga registros formales de la tabla directiva.
    final directivaData = await SupabaseService.client
        .from('directiva')
        .select('id_miembro, dpi_usuario, cargo, periodo_inicio, periodo_fin, imagen_url, usuarios(nombres, apellidos, telefono, rol)')
        .order('id_miembro');

    final miembros = List<Map<String, dynamic>>.from(directivaData)
        .where((m) {
          final u = m['usuarios'];
          return u is Map && u['rol']?.toString() == 'Directivo';
        })
        .toList();
    return miembros;

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _cargarDirectiva(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar directiva: ${snapshot.error}'));
                }

                final miembros = snapshot.data ?? [];
                if (miembros.isEmpty) {
                  return const Center(child: Text('Aún no hay miembros registrados.'));
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.60,
                  ),
                  padding: const EdgeInsets.all(16),
                  itemCount: miembros.length,
                  itemBuilder: (context, index) {
                    final m = miembros[index];
                    final usuario = m['usuarios'] is Map ? Map<String, dynamic>.from(m['usuarios'] as Map) : <String, dynamic>{};
                    final nombre = '${usuario['nombres'] ?? ''} ${usuario['apellidos'] ?? ''}'.trim();
                    return _buildDirectivaCard(
                      nombre.isEmpty ? 'Sin nombre' : nombre,
                      m['cargo']?.toString() ?? 'Sin cargo',
                      m['imagen_url']?.toString(),
                      usuario['telefono']?.toString(),
                      m['periodo_inicio']?.toString(),
                      m['periodo_fin']?.toString(),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 20),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Directiva', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirWhatsApp(String telefono) async {
    final soloNumeros = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloNumeros.isEmpty) return;

    final numero = soloNumeros.startsWith('502') ? soloNumeros : '502$soloNumeros';
    final uri = Uri.parse('https://wa.me/$numero');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir WhatsApp');
    }
  }

  Widget _buildDirectivaCard(String name, String role, String? imageUrl, String? telefono, String? periodoInicio, String? periodoFin) {
    ImageProvider imageProvider;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageProvider = NetworkImage(imageUrl);
    } else {
      imageProvider = const AssetImage('assets/perfil.jpg');
    }

    final telefonoLimpio = telefono?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final telefonoTexto = telefonoLimpio.isEmpty
        ? 'Sin teléfono'
        : (telefonoLimpio.startsWith('502') ? '+$telefonoLimpio' : '+502 $telefonoLimpio');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 38, backgroundImage: imageProvider),
            const SizedBox(height: 10),
            Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(role, textAlign: TextAlign.center, style: const TextStyle(color: primaryColor)),
            const SizedBox(height: 4),
            Text(
              'Inicio: ${periodoInicio ?? 'Sin fecha'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              'Fin: ${periodoFin ?? 'Vigente'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(telefonoTexto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: telefonoLimpio.isEmpty ? null : () => _abrirWhatsApp(telefonoLimpio),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.chat, color: Colors.white, size: 16),
                label: const Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
