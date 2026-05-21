import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
}

class AppSession {
  static String? dpiUsuario;
  static String? rolUsuario;
  static String? authUserId;
  static String? correoUsuario;

  static bool get esDirectiva => rolUsuario == 'Directivo' || rolUsuario == 'Admin';
  static bool get esAdmin => rolUsuario == 'Admin';

  static Future<void> cargarDesdeAuth() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    authUserId = user.id;
    correoUsuario = user.email;

    final usuario = await SupabaseService.client
        .from('usuarios')
        .select('dpi, rol, correo')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (usuario != null) {
      dpiUsuario = usuario['dpi']?.toString();
      rolUsuario = usuario['rol']?.toString();
      correoUsuario = usuario['correo']?.toString() ?? user.email;
    }
  }

  static Future<void> cerrarSesion() async {
    dpiUsuario = null;
    rolUsuario = null;
    authUserId = null;
    correoUsuario = null;
    await SupabaseService.client.auth.signOut();
  }
}
