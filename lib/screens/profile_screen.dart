import 'package:flutter/material.dart';
import 'package:flutter_app_comunitaria/services/supabase_service.dart';
import 'package:flutter_app_comunitaria/utilidades/edit_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryColor = Color(0xFF2E9461);
  late Future<Map<String, dynamic>?> _perfilFuture;

  @override
  void initState() {
    super.initState();
    _perfilFuture = _cargarPerfil();
  }

  Future<Map<String, dynamic>?> _cargarPerfil() async {
    final dpi = AppSession.dpiUsuario;
    if (dpi == null) return null;

    final data = await SupabaseService.client
        .from('usuarios')
        .select('dpi, correo, nombres, apellidos, telefono, rol, foto_perfil_url, sectores_aldea(nombre_sector)')
        .eq('dpi', dpi)
        .maybeSingle();

    return data;
  }

  void _recargarPerfil() {
    setState(() {
      _perfilFuture = _cargarPerfil();
    });
  }

  Future<void> _editarPerfil(Map<String, dynamic> usuario) async {
    final actualizado = await EditProfile.show(context, usuario);
    if (actualizado == true) _recargarPerfil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _perfilFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar perfil: ${snapshot.error}'));
                }

                final usuario = snapshot.data;
                if (usuario == null) {
                  return const Center(child: Text('No hay usuario en sesión.'));
                }

                final sector = usuario['sectores_aldea'] as Map<String, dynamic>?;
                final nombreCompleto = '${usuario['nombres'] ?? ''} ${usuario['apellidos'] ?? ''}'.trim();
                final fotoUrl = usuario['foto_perfil_url']?.toString();

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                            ? NetworkImage(fotoUrl)
                            : const AssetImage('assets/perfil.jpg') as ImageProvider,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nombreCompleto,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        usuario['rol']?.toString() ?? '',
                        style: const TextStyle(fontSize: 14, color: primaryColor, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 25),
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProfileField('Nombre completo:', nombreCompleto),
                                _buildProfileField('No. de DPI:', usuario['dpi']?.toString() ?? ''),
                                _buildProfileField('Correo:', usuario['correo']?.toString() ?? ''),
                                _buildProfileField('No. de teléfono:', usuario['telefono']?.toString() ?? ''),
                                _buildProfileField('Sector/Aldea:', sector?['nombre_sector']?.toString() ?? ''),
                                _buildProfileField('Rol:', usuario['rol']?.toString() ?? ''),
                                if (AppSession.esDirectiva)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Modo Directiva habilitado',
                                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: primaryColor),
                              onPressed: () => _editarPerfil(usuario),
                            ),
                          ),
                        ],
                      ),
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
          const Expanded(child: Text('Perfil', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
