import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_comunitaria/screens/home_screen.dart';
import 'package:flutter_app_comunitaria/screens/register_screen.dart';
import 'package:flutter_app_comunitaria/screens/reset_password_screen.dart';
import 'package:flutter_app_comunitaria/services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final correo = _correoController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      _showMessage('Ingresá correo y contraseña.');
      return;
    }

    setState(() => _loading = true);

    try {
      final authResponse = await SupabaseService.client.auth.signInWithPassword(
        email: correo,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        _showMessage('No se pudo iniciar sesión.');
        return;
      }

      final usuario = await SupabaseService.client
          .from('usuarios')
          .select('dpi, rol, auth_user_id, correo')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (usuario == null) {
        await SupabaseService.client.auth.signOut();
        _showMessage('La cuenta existe en Auth, pero no tiene perfil en usuarios.');
      } else {
        AppSession.dpiUsuario = usuario['dpi']?.toString();
        AppSession.rolUsuario = usuario['rol']?.toString();
        AppSession.authUserId = user.id;
        AppSession.correoUsuario = usuario['correo']?.toString() ?? user.email;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      _showMessage('Error al iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                  child: Container(height: 250, color: LoginScreen.primaryColor),
                ),
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const Text(
                        "Bienvenido a la app\nMi Nimapá",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Image.asset('assets/nimapa_logotipo.png', height: 90, fit: BoxFit.contain),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Inicio de Sesión",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: LoginScreen.primaryColor),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email, color: Colors.grey),
                      hintText: 'Correo electrónico',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.vpn_key, color: Colors.grey),
                      hintText: 'Contraseña',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ResetPasswordScreen())),
                      child: const Text("Olvidé la contraseña", style: TextStyle(color: LoginScreen.primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(backgroundColor: LoginScreen.primaryColor),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("INGRESAR", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                      child: const Text.rich(
                        TextSpan(
                          text: "¿Aún no te has registrado? ",
                          style: TextStyle(color: Colors.grey),
                          children: [
                            TextSpan(text: "Regístrate ya.", style: TextStyle(color: LoginScreen.primaryColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
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
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 4, size.height, size.width / 2, size.height - 30);
    path.quadraticBezierTo(size.width * 3 / 4, size.height - 60, size.width, size.width * 0 + size.height - 20);
    path.lineTo(size.width, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
