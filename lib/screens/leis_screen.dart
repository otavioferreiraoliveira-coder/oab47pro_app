import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../services/gemini_service.dart';
import '../services/deepseek_service.dart';

const _bloco1 = [
  _Lei('etica',          'Ética Profissional',       'https://www.planalto.gov.br/ccivil_03/leis/l8906.htm'),
  _Lei('constitucional', 'Direito Constitucional',   'https://www.planalto.gov.br/ccivil_03/constituicao/constituicao.htm'),
  _Lei('administrativo', 'Direito Administrativo',   'https://www.planalto.gov.br/ccivil_03/leis/l9784.htm'),
  _Lei('civil',          'Direito Civil',             'https://www.planalto.gov.br/ccivil_03/leis/2002/l10406compilada.htm'),
  _Lei('proc_civil',     'Direito Processual Civil', 'https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2015/lei/l13105.htm'),
  _Lei('penal',          'Direito Penal',             'https://www.planalto.gov.br/ccivil_03/decreto-lei/del2848compilado.htm'),
  _Lei('proc_penal',     'Direito Processual Penal', 'https://www.planalto.gov.br/ccivil_03/decreto-lei/del3689.htm'),
];

class _Lei {
  final String id, nome, url;
  const _Lei(this.id, this.nome, this.url);
}

class LeisScreen extends StatefulWidget {
  const LeisScreen({super.key});
  @override
  State<LeisScreen> createState() => _LeisScreenState();
}

class _LeisScreenState extends State<LeisScreen> {
  final FlutterTts _tts = FlutterTts();
  final Map<int, String> _cache = {};
  final Map<int, bool> _carregando = {};
  int? _ouvintoIdx;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('pt-BR');
    _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() { if (mounted) setState(() => _ouvintoIdx = null); });
    _tts.setErrorHandler((_) { if (mounted) setState(() => _ouvintoIdx = null); });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _ouvir(int i) async {
    if (_ouvintoIdx == i) {
      await _tts.stop();
      setState(() => _ouvintoIdx = null);
      return;
    }
    if (_ouvintoIdx != null) await _tts.stop();

    if (_cache.containsKey(i)) {
      setState(() => _ouvintoIdx = i);
      await _tts.speak(_cache[i]!);
      return;
    }

    final app = context.read<AppProvider>();
    final cfg = app.estado.config;
    if (!cfg.temChave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure a chave de IA em Configurações'), backgroundColor: red),
      );
      return;
    }

    setState(() => _carregando[i] = true);
    final d = _bloco1[i];
    final prompt = '''Você é professor de Direito para o Exame OAB 1ª Fase.
Disciplina: ${d.nome}
Referência legal: ${d.url}

Leia e explique os artigos mais importantes desta lei cobrados no Exame de Ordem.
Cite os artigos exatos com número e texto resumido. Seja direto e preciso.
NUNCA invente artigos. Máximo 400 palavras.''';

    try {
      final String txt;
      if (cfg.provedorAtivo == 'deepseek') {
        txt = await DeepSeekService.generate(
          apiKey: cfg.deepseek, model: cfg.deepseekModelo,
          prompt: prompt, maxTokens: 900,
        );
      } else {
        txt = await GeminiService.generateWithSystem(
          apiKey: cfg.gemini, model: cfg.modelo,
          prompt: prompt, maxTokens: 900,
        );
      }
      _cache[i] = txt;
      setState(() { _carregando.remove(i); _ouvintoIdx = i; });
      await _tts.speak(txt);
    } catch (e) {
      if (mounted) {
        setState(() => _carregando.remove(i));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro IA: $e'), backgroundColor: red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.menu_book_outlined, color: orange, size: 18),
          SizedBox(width: 8),
          Text('Leitura de Leis — Bloco 1'),
        ]),
        automaticallyImplyLeading: false,
        actions: [
          if (_ouvintoIdx != null)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: orange, size: 22),
              tooltip: 'Parar leitura',
              onPressed: () async { await _tts.stop(); setState(() => _ouvintoIdx = null); },
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _bloco1.length,
        itemBuilder: (_, i) {
          final d = _bloco1[i];
          final carregando = _carregando[i] == true;
          final ouvindo = _ouvintoIdx == i;
          final temCache = _cache.containsKey(i);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: navyLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ouvindo ? orange : navyBorder),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${i + 1}',
                  style: const TextStyle(color: orange, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(d.nome,
                  style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: carregando ? null : () => _ouvir(i),
                  icon: carregando
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: orange))
                      : Icon(ouvindo ? Icons.stop : Icons.volume_up,
                          size: 15, color: ouvindo ? red : orange),
                  label: Text(
                    carregando ? 'IA…' : (ouvindo ? 'Parar' : (temCache ? '▶ Reouvir' : '🔊 Ouvir')),
                    style: TextStyle(
                      color: ouvindo ? red : orange, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ouvindo ? red : navyBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
