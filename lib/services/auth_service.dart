import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static Session? get currentSession => _client.auth.currentSession;
  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<void> signIn(String email, String password) async {
    final resp = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (resp.user == null) throw Exception('Credenciais inválidas');
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
