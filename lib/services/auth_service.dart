import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  static final _client = Supabase.instance.client;
  // IMPORTANTE: o scheme NÃO pode conter underscore — schemes de URI inválidos
  // (RFC 3986) fazem o GoTrue/Supabase rejeitar o redirect e cair no Site URL.
  static const _redirectUrl = 'com.oab47pro.app://login-callback';

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

  static Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
