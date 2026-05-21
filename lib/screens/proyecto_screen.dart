import 'package:flutter/material.dart';
import 'package:flutter_app_comunitaria/services/supabase_service.dart';

class ProyectoScreen extends StatelessWidget {
  const ProyectoScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  Future<List<Map<String, dynamic>>> _cargarProyectos() async {
    final data = await SupabaseService.client
        .from('proyectos')
        .select()
        .order('fecha_inicio', ascending: false);

    return List<Map<String, dynamic>>.from(data);
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
              future: _cargarProyectos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar proyectos: ${snapshot.error}'));
                }

                final proyectos = snapshot.data ?? [];
                if (proyectos.isEmpty) {
                  return const Center(child: Text('Aún no hay proyectos registrados.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: proyectos.length,
                  itemBuilder: (context, index) {
                    final p = proyectos[index];
                    return _buildProyectoCard(p);
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
      padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 25),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, color: Colors.white)),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Proyectos de la Comunidad', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProyectoCard(Map<String, dynamic> proyecto) {
    final nombre = proyecto['nombre_proyecto']?.toString() ?? 'Sin nombre';
    final estado = proyecto['estado']?.toString() ?? 'Sin estado';
    final descripcion = proyecto['descripcion']?.toString() ?? '';
    final presupuesto = proyecto['presupuesto_aprox']?.toString() ?? '0';
    final fechaInicio = proyecto['fecha_inicio']?.toString() ?? 'Sin fecha';
    final imagenUrl = proyecto['imagen_url']?.toString();
    final tieneImagen = imagenUrl != null && imagenUrl.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tieneImagen) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imagenUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Text('No se pudo cargar la imagen'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Estado: $estado', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(descripcion),
            const SizedBox(height: 8),
            Text('Presupuesto: Q$presupuesto'),
            Text('Inicio: $fechaInicio'),
          ],
        ),
      ),
    );
  }
}
