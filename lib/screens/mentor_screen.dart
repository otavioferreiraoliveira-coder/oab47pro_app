import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../services/gemini_service.dart';
import '../services/deepseek_service.dart';

class MentorScreen extends StatefulWidget {
  const MentorScreen({super.key});

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _carregando = false;
  Map<String, dynamic>? _convAtual;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppProvider>();
      await app.sincronizar();
      _inicializar();
    });
    // Polling a cada 12s enquanto a tela está aberta
    _syncTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      await app.sincronizar();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _inicializar() {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    final convs = app.estado.conversas.where((c) => c['deleted'] != true).toList();
    setState(() {
      if (_convAtual == null) {
        // Primeira abertura: carrega a conversa mais recente
        _convAtual = convs.isNotEmpty
            ? Map<String, dynamic>.from(convs.first)
            : _novaConv();
      } else {
        // Após sync: atualiza a conversa atual se veio do remoto com msgs novas
        final id = _convAtual!['id'] as String;
        final remota = convs.cast<Map<String, dynamic>?>()
            .firstWhere((c) => c?['id'] == id, orElse: () => null);
        if (remota != null) {
          final localMsgs = (_convAtual!['msgs'] as List?)?.length ?? 0;
          final remotaMsgs = (remota['msgs'] as List?)?.length ?? 0;
          if (remotaMsgs > localMsgs) _convAtual = Map<String, dynamic>.from(remota);
        }
      }
    });
  }

  Map<String, dynamic> _novaConv() => {
        'id': 'c_${DateTime.now().millisecondsSinceEpoch}',
        'titulo': 'Nova conversa',
        'ts': DateTime.now().millisecondsSinceEpoch,
        'msgs': <Map<String, dynamic>>[],
      };

  List<Map<String, dynamic>> get _msgs =>
      (_convAtual?['msgs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  void _salvarConv() {
    if (_convAtual == null) return;
    final app = context.read<AppProvider>();
    final convs = app.estado.conversas;
    final id = _convAtual!['id'] as String;
    final idx = convs.indexWhere((c) => c['id'] == id);
    final copia = Map<String, dynamic>.from(_convAtual!);
    copia['msgs'] = List<Map<String, dynamic>>.from(_msgs);
    if (idx >= 0) {
      convs[idx] = copia;
    } else {
      convs.insert(0, copia);
    }
    app.sincronizar();
  }

  void _iniciarNovaConversa() {
    _salvarConv();
    setState(() {
      _convAtual = _novaConv();
    });
  }

  void _carregarConversa(Map<String, dynamic> conv) {
    _salvarConv();
    setState(() {
      _convAtual = Map<String, dynamic>.from(conv);
    });
    Navigator.pop(context);
  }

  void _deletarConversa(String id) {
    final app = context.read<AppProvider>();
    final convs = app.estado.conversas;
    final idx = convs.indexWhere((c) => c['id'] == id);
    if (idx >= 0) {
      // Tombstone: marca como deletado com ts novo — evita sync restaurar
      convs[idx] = {
        ...convs[idx],
        'deleted': true,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
    }
    SyncService.saveLocal(app.estado);
    app.sincronizar();
    final visiveis = convs.where((c) => c['deleted'] != true).toList();
    if (_convAtual?['id'] == id) {
      setState(() {
        _convAtual = visiveis.isNotEmpty
            ? Map<String, dynamic>.from(visiveis.first)
            : _novaConv();
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    final app = context.read<AppProvider>();
    final cfg = app.estado.config;

    if (!cfg.temChave) {
      setState(() {
        _msgs.add({'role': 'model', 'text': 'Configure sua chave Gemini ou DeepSeek em Configurações para usar o Mentor.'});
      });
      return;
    }

    _ctrl.clear();

    if (_msgs.isEmpty) {
      _convAtual!['titulo'] = texto.length > 48 ? '${texto.substring(0, 48)}…' : texto;
      _convAtual!['ts'] = DateTime.now().millisecondsSinceEpoch;
    }

    setState(() {
      _msgs.add({'role': 'user', 'text': texto});
      _carregando = true;
    });
    _rolarFim();

    final kpis = app.kpis();
    final prios = app.prioridades().take(5).toList();
    final priosTxt = prios.asMap().entries
        .map((e) => '${e.key + 1}. ${e.value['nome']} (${e.value['resp'] != null ? "${((e.value['taxa'] as double? ?? 0) * 100).round()}% de acerto" : "não praticada"})')
        .join('\n');

    final systemPrompt = '''Você é o MENTOR IMPLACÁVEL do Ceisc para o 47º Exame de Ordem (OAB).
Persona: direto, exigente, motivador sem ser fofo; foco total em aprovação na 1ª fase (30/08/2026) e 2ª fase (18/10/2026).
Regras: fundamente sempre na lei vigente (Planalto), NUNCA invente artigo/súmula; respostas práticas e acionáveis; máximo ~300 palavras.
DESEMPENHO DO ALUNO:
- ${kpis.total} questões resolvidas, ${kpis.taxa == null ? "—" : "${(kpis.taxa! * 100).round()}%"} de acerto
- ${kpis.sims} simulados; projeção: ${kpis.proj == null ? "sem dados" : "${kpis.proj}/80 (corte: 40)"}
- Prioridades:\n$priosTxt''';

    final historico = _msgs
        .where((m) => m['role'] == 'user' || m['role'] == 'model')
        .toList()
        .reversed
        .take(16)
        .toList()
        .reversed
        .map((m) => '${m['role'] == 'user' ? 'ALUNO' : 'MENTOR'}: ${m['text']}')
        .join('\n\n');

    try {
      String resp;
      if (cfg.provedorAtivo == 'deepseek') {
        resp = await DeepSeekService.generate(
          apiKey: cfg.deepseek,
          model: cfg.deepseekModelo,
          prompt: '$historico\n\nMENTOR:',
          systemPrompt: systemPrompt,
          temperature: 0.5,
          maxTokens: 1200,
        );
      } else {
        resp = await GeminiService.generateWithSystem(
          apiKey: cfg.gemini,
          model: cfg.modelo,
          systemPrompt: systemPrompt,
          prompt: '$historico\n\nMENTOR:',
          temperature: 0.5,
          maxTokens: 1200,
        );
      }
      setState(() {
        _msgs.add({'role': 'model', 'text': resp});
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _msgs.add({'role': 'model', 'text': '⚠ $e\n\nVerifique a chave em Configurações.'});
        _carregando = false;
      });
    }
    _salvarConv();
    _rolarFim();
  }

  void _rolarFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _abrirHistorico() {
    final app = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: navyLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(builder: (ctx, setModal) {
        final convs = app.estado.conversas.where((c) => c['deleted'] != true).toList();
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Text('Conversas',
                        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _iniciarNovaConversa();
                      },
                      icon: const Icon(Icons.add, size: 16, color: orange),
                      label: const Text('Nova', style: TextStyle(color: orange, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: convs.isEmpty
                    ? const Center(
                        child: Text('Nenhuma conversa ainda',
                            style: TextStyle(color: textMuted, fontSize: 13)))
                    : ListView.separated(
                        itemCount: convs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (_, i) {
                          final c = convs[i];
                          final ativo = _convAtual?['id'] == c['id'];
                          return ListTile(
                            selected: ativo,
                            selectedTileColor: orange.withValues(alpha: 0.08),
                            title: Text(
                              c['titulo'] as String? ?? 'Conversa',
                              style: TextStyle(
                                  color: ativo ? orange : textPrimary,
                                  fontSize: 13,
                                  fontWeight: ativo ? FontWeight.w600 : FontWeight.w400),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _formatarData(c['ts'] as int? ?? 0),
                              style: const TextStyle(color: textMuted, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: textMuted),
                              onPressed: () {
                                _deletarConversa(c['id'] as String);
                                setModal(() {});
                              },
                            ),
                            onTap: () => _carregarConversa(c),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _formatarData(int ts) {
    if (ts == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.auto_awesome, color: orange, size: 16),
              SizedBox(width: 6),
              Text('Mentor Implacável', style: TextStyle(fontSize: 16)),
            ]),
            if (_convAtual != null && (_convAtual!['titulo'] as String?) != 'Nova conversa')
              Text(
                _convAtual!['titulo'] as String? ?? '',
                style: const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            tooltip: 'Nova conversa',
            onPressed: _iniciarNovaConversa,
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined, size: 20),
            tooltip: 'Histórico',
            onPressed: _abrirHistorico,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: (_msgs.isEmpty ? 1 : _msgs.length) + (_carregando ? 1 : 0),
              itemBuilder: (_, i) {
                if (_msgs.isEmpty && i == 0) {
                  return _buildBubble(false,
                      'Sou seu Mentor para o 47º Exame. Conheço suas estatísticas e as datas da prova. O que vai ser?');
                }
                if (i == _msgs.length) return _buildTyping();
                final m = _msgs[i];
                return _buildBubble(m['role'] == 'user', m['text'] as String? ?? '');
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
                        hintText: 'Pergunte sobre direito, seu plano, desempenho…',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  Widget _buildBubble(bool isUser, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? orange : navyLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: isUser ? null : Border.all(color: navyBorder),
              ),
              child: Text(
                texto,
                style: TextStyle(
                    color: isUser ? Colors.white : textPrimary,
                    fontSize: 14,
                    height: 1.45),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
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
            width: 28, height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: orange, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: navyLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14),
                bottomRight: Radius.circular(14), bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: navyBorder),
            ),
            child: const SizedBox(
              width: 40, height: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_Dot(delay: 0), _Dot(delay: 150), _Dot(delay: 300)],
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        width: 8, height: 8,
        decoration: BoxDecoration(color: textMuted, borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
