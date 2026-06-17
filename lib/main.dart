import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'config/theme.dart';
import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey); // ignore: deprecated_member_use
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const OAB47ProApp(),
    ),
  );
}

class OAB47ProApp extends StatelessWidget {
  const OAB47ProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OAB47PRO',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  bool _loggedIn = Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    // Armazena a subscription para evitar garbage collection
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final logado = data.session != null;
      if (logado != _loggedIn) {
        setState(() => _loggedIn = logado);
        if (logado) context.read<AppProvider>().carregar();
      }
    });
    if (_loggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppProvider>().carregar();
      });
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _loggedIn ? const HomeShell() : const LoginScreen();
  }
}
