import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_comunitaria/services/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _dpiController = TextEditingController();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<Map<String, dynamic>> _sectores = [];
  int? _idSectorSeleccionado;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cargarSectores();
  }

  @override
  void dispose() {
    _dpiController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _cargarSectores() async {
    try {
      final data = await SupabaseService.client.from('sectores_aldea').select().order('nombre_sector');
      setState(() => _sectores = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _showMessage('Error al cargar sectores: $e');
    }
  }

  bool _telefonoGuatemalaValido(String telefono) {
    final soloNumeros = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    return soloNumeros.length == 8;
  }

  Future<void> _registrar() async {
    final dpi = _dpiController.text.trim();
    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final correo = _correoController.text.trim().toLowerCase();
    final telefono = _telefonoController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo);

    if (dpi.length != 13 || nombres.isEmpty || apellidos.isEmpty || correo.isEmpty || password.isEmpty || _idSectorSeleccionado == null) {
      _showMessage('Completá DPI, nombres, apellidos, correo, sector y contraseña.');
      return;
    }

    if (!correoValido) {
      _showMessage('Ingresá un correo válido.');
      return;
    }

    if (telefono.isNotEmpty && !_telefonoGuatemalaValido(telefono)) {
      _showMessage('Ingresá un teléfono válido de Guatemala, solo 8 dígitos.');
      return;
    }

    if (password.length < 6) {
      _showMessage('La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _loading = true);

    try {
      final authResponse = await SupabaseService.client.auth.signUp(
        email: correo,
        password: password,
        data: {
          'dpi': dpi,
          'nombres': nombres,
          'apellidos': apellidos,
          'telefono': telefono.isEmpty ? null : '+502$telefono',
        },
      );

      final user = authResponse.user;
      if (user == null) {
        _showMessage('Revisá tu correo para confirmar la cuenta antes de iniciar sesión.');
        return;
      }

      await SupabaseService.client.from('usuarios').insert({
        'dpi': dpi,
        'auth_user_id': user.id,
        'correo': correo,
        'nombres': nombres,
        'apellidos': apellidos,
        'telefono': telefono.isEmpty ? null : '+502$telefono',
        'id_sector': _idSectorSeleccionado,
        'rol': 'Vecino',
      });

      await SupabaseService.client.auth.signOut();

      if (!mounted) return;
      _showMessage('Usuario registrado. Si Supabase pide confirmación, revisá tu correo antes de iniciar sesión.');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Error al registrar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildTextField(
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool obscureText = false,
    List<TextInputFormatter>? formatters,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      inputFormatters: formatters,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5)),
          child: Icon(icon, color: Colors.grey[600]),
        ),
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _telefonoController,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5)),
          child: Icon(Icons.phone, color: Colors.grey[600]),
        ),
        prefixText: '+502 ',
        hintText: 'Teléfono para contacto/WhatsApp',
        helperText: 'Opcional. Ingresá solo 8 dígitos.',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                ClipPath(
                  clipper: HeaderClipper(),
                  child: Container(height: 200, color: RegisterScreen.primaryColor),
                ),
                const Positioned(
                  top: 80,
                  left: 40,
                  child: Text('Bienvenido a la app', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: RegisterScreen.primaryColor)),
                  const SizedBox(height: 20),
                  _buildTextField(_dpiController, Icons.badge, 'DPI / CUI', keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)]),
                  const SizedBox(height: 15),
                  _buildTextField(_nombresController, Icons.person, 'Nombres'),
                  const SizedBox(height: 15),
                  _buildTextField(_apellidosController, Icons.person_outline, 'Apellidos'),
                  const SizedBox(height: 15),
                  _buildTextField(_correoController, Icons.email, 'Correo electrónico', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  _buildPhoneField(),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    value: _idSectorSeleccionado,
                    decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on, color: Colors.grey), hintText: 'Sector / Aldea'),
                    items: _sectores.map((sector) => DropdownMenuItem<int>(value: sector['id_sector'] as int, child: Text(sector['nombre_sector'].toString()))).toList(),
                    onChanged: (value) => setState(() => _idSectorSeleccionado = value),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(_passwordController, Icons.vpn_key, 'Contraseña', obscureText: true),
                  const SizedBox(height: 15),
                  _buildTextField(_confirmPasswordController, Icons.vpn_key_outlined, 'Confirmar contraseña', obscureText: true),
                  const SizedBox(height: 12),
                  const Text(
                    'La contraseña se guarda de forma segura en Supabase Auth. El teléfono queda solo para contacto/WhatsApp.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _registrar,
                      style: ElevatedButton.styleFrom(backgroundColor: RegisterScreen.primaryColor),
                      child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('REGISTRAR', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text.rich(TextSpan(text: '¿Ya tienes una cuenta? ', style: TextStyle(color: Colors.grey, fontSize: 12), children: [TextSpan(text: 'Inicia Sesión aquí', style: TextStyle(color: RegisterScreen.primaryColor, fontWeight: FontWeight.bold))])),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(size.width / 4, size.height, size.width / 2, size.height - 20);
    path.quadraticBezierTo(size.width * 3 / 4, size.height - 40, size.width, size.height - 10);
    path.lineTo(size.width, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
