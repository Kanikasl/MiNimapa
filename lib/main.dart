import 'package:flutter/material.dart';
import 'package:app_comunitaria/screens/change_password_screen.dart';
import 'package:app_comunitaria/screens/home_screen.dart';
import 'package:app_comunitaria/screens/login_screen.dart';
import 'package:app_comunitaria/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ftiokcyzmvqbfeysiwgm.supabase.co',
    anonKey: 'sb_publishable_dQFEll1dGtWZJ9UXXBp72Q_57PFp5VJ',
  );

  runApp(const MainApp());
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MiNimapa',
      home: const AuthGate(),
    );
  }
}


class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _logueado = false;

  @override
  void initState() {
    super.initState();
    _verificarSesion();
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        appNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          (route) => false,
        );
      }
    });
  }

  Future<void> _verificarSesion() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      await AppSession.cargarDesdeAuth();
      _logueado = AppSession.dpiUsuario != null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _logueado ? const HomeScreen() : const LoginScreen();
  }
}
