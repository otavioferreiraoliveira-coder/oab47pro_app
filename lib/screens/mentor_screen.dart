import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../services/gemini_service.dart';

class _Mensagem {
  final bool isUser;
  final String texto;
  const _Mensagem({required this.isUser, required this.texto});
}

class MentorScreen extends StatefulWidget {
  const MentorScreen({super.key});

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Mensagem> _msgs = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _msgs.add(const _Mensagem(
      isUser: false,
      texto:
          'Olá! Sou seu Mentor OAB. Posso ajudar com dúvidas jurídicas, estratégias de estudo e análise do seu desempenho. Como posso ajudar?',
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    final app = context.read<AppProvider>();
    final apiKey = app.estado.config.gemini;
    final model = app.estado.config.modelo;

    _ctrl.clear();
    setState(() {
      _msgs.add(_Mensagem(isUser: true, texto: texto));
      _carregando = true;
    });
    _rolarFim();

    if (apiKey.isEmpty) {
      setState(() {
        _msgs.add(const _Mensagem(
            isUser: false,
            texto:
                'Para usar o Mentor, configure sua chave Gemini em Configurações.'));
        _carregando = false;
      });
      return;
    }

    try {
      final kpis = app.kpis();
      final contexto = kpis.total > 0
          ? 'O aluno respondeu ${kpis.total} questões com ${((kpis.taxa ?? 0) * 100).round()}% de acerto e fez ${kpis.sims} simulados.'
          : '';
      final prompt =
          'Você é um mentor especializado no Exame da OAB (Ordem dos Advogados do Brasil), 1ª fase. $contexto\n\nPergunta do aluno: $texto\n\nResponda de forma objetiva, didática e direta. Máximo 300 palavras.';
      final resp = await GeminiService.generate(
          apiKey: apiKey, model: model, prompt: prompt);
      setState(() {
        _msgs.add(_Mensagem(isUser: false, texto: resp));
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _msgs.add(_Mensagem(isUser: false, texto: 'Erro: $e'));
        _carregando = false;
      });
    }
    _rolarFim();
  }

  void _rolarFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: orange, size: 18),
            SizedBox(width: 8),
            Text('Mentor IA'),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length + (_carregando ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _msgs.length) return _buildTyping();
                return _buildBubble(_msgs[i]);
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(),
                      style: const TextStyle(color: textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Pergunte algo…',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _carregando ? null : _enviar,
                    icon: const Icon(Icons.send, size: 18),
                    style: IconButton.styleFrom(backgroundColor: orange),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_Mensagem m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.isUser) ...[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: orange, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.isUser ? orange : navyLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(m.isUser ? 14 : 4),
                  bottomRight: Radius.circular(m.isUser ? 4 : 14),
                ),
                border: m.isUser
                    ? null
                    : Border.all(color: navyBorder),
              ),
              child: Text(
                m.texto,
                style: TextStyle(
                  color: m.isUser ? Colors.white : textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (m.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: orange, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: navyLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: navyBorder),
            ),
            child: const SizedBox(
              width: 40,
              height: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Dot(delay: 0),
                  _Dot(delay: 150),
                  _Dot(delay: 300),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
            color: textMuted, borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
