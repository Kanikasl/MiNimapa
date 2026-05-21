import 'package:flutter/material.dart';
import 'package:app_comunitaria/screens/login_screen.dart';
import 'package:app_comunitaria/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardarPassword() async {
    final pass = _password.text.trim();
    final confirmar = _confirmar.text.trim();

    if (pass.length < 6) {
      _mensaje('La contraseña debe tener mínimo 6 caracteres.');
      return;
    }
    if (pass != confirmar) {
      _mensaje('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      await SupabaseService.client.auth.signOut();
      if (!mounted) return;
      _mensaje('Contraseña actualizada. Iniciá sesión nuevamente.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _mensaje('Error al actualizar contraseña: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: const Text('Nueva contraseña'),
        backgroundColor: ChangePasswordScreen.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresá tu nueva contraseña para completar la recuperación.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock),
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmar,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                labelText: 'Confirmar contraseña',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _guardarPassword,
                style: ElevatedButton.styleFrom(backgroundColor: ChangePasswordScreen.primaryColor),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('GUARDAR CONTRASEÑA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
