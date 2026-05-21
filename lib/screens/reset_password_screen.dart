import 'package:flutter/material.dart';
import 'package:flutter_app_comunitaria/services/supabase_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  static const Color primaryColor = Color(0xFF2E9461);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _correoController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _enviarRecuperacion() async {
    final correo = _correoController.text.trim().toLowerCase();
    if (correo.isEmpty) {
      _mensaje('Ingresá tu correo.');
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(
        correo,
        redirectTo: 'com.example.flutter_app_comunitaria://reset-password',
      );
      _mensaje('Te enviamos un correo para recuperar tu contraseña.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _mensaje('Error al enviar recuperación: $e');
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
        title: const Text('Recuperar contraseña'),
        backgroundColor: ResetPasswordScreen.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresá tu correo. Al abrir el enlace desde el celular, la app te pedirá la nueva contraseña.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _correoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email),
                hintText: 'Correo electrónico',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _enviarRecuperacion,
                style: ElevatedButton.styleFrom(backgroundColor: ResetPasswordScreen.primaryColor),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ENVIAR CORREO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
