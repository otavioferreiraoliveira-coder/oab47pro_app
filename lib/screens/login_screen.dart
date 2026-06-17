import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false, _loadingGoogle = false;
  String? _erro;
  bool _passVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _erro = 'Preencha e-mail e senha.');
      return;
    }
    setState(() { _loading = true; _erro = null; });
    try {
      await AuthService.signIn(email, pass);
    } catch (e) {
      if (mounted) setState(() {
        _erro = e.toString().replaceAll('Exception: ', '');
        _pass.clear();
        _loading = false;
      });
    }
  }

  Future<void> _entrarGoogle() async {
    setState(() { _loadingGoogle = true; _erro = null; });
    try {
      await AuthService.signInWithGoogle();
      // Abre browser — retorno via deep link tratado automaticamente pelo supabase_flutter
    } catch (e) {
      if (mounted) setState(() {
        _erro = e.toString().replaceAll('Exception: ', '');
        _loadingGoogle = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -1),
                        children: [
                          TextSpan(text: 'OAB'),
                          TextSpan(text: '47', style: TextStyle(color: orange)),
                          TextSpan(text: 'PRO'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(child: Text('Preparação Exame de Ordem', style: TextStyle(color: textSecondary, fontSize: 13))),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: navyLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: navyBorder)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Acesso restrito', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Entre com e-mail/senha ou Google.', style: TextStyle(color: textSecondary, fontSize: 13)),
                      const SizedBox(height: 20),

                      // Botão Google
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: (_loading || _loadingGoogle) ? null : _entrarGoogle,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: navyBorder),
                            foregroundColor: textPrimary,
                          ),
                          child: _loadingGoogle
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textSecondary))
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  _GoogleIcon(),
                                  const SizedBox(width: 10),
                                  const Text('Entrar com Google'),
                                ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Expanded(child: Divider(color: navyBorder)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('ou', style: TextStyle(color: textMuted.withValues(alpha: 0.8), fontSize: 12))),
                        const Expanded(child: Divider(color: navyBorder)),
                      ]),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        style: const TextStyle(color: textPrimary),
                        decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined, size: 18, color: textMuted)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        obscureText: !_passVisible,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _entrar(),
                        style: const TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: textMuted),
                          suffixIcon: IconButton(
                            icon: Icon(_passVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: textMuted),
                            onPressed: () => setState(() => _passVisible = !_passVisible),
                          ),
                        ),
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: red.withValues(alpha: 0.3))),
                          child: Text(_erro!, style: const TextStyle(color: red, fontSize: 13)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_loading || _loadingGoogle) ? null : _entrar,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Entrar com E-mail'),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Center(child: Text('Acesso exclusivo — conta gerenciada no painel Supabase.', style: TextStyle(color: textMuted, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18, height: 18,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // Quatro quadrantes coloridos
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.5708, 1.5708, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -3.1416, 1.5708, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 3.1416, 1.5708, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 1.5708, 1.5708, true, paint);

    // Círculo branco central
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.55, paint);

    // Faixa direita azul (parte do G)
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(cx, cy - r * 0.22, r, r * 0.44), paint);

    // Círculo branco central novamente para limpar
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.38, paint);
  }

  @override bool shouldRepaint(_) => false;
}
