import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
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
  // IA cache/state
  final Map<int, String> _cacheIA = {};
  final Map<int, bool> _carregandoIA = {};
  // Planalto cache/state
  final Map<int, String> _cacheDir = {};
  final Map<int, bool> _carregandoDir = {};
  // null = parado; 'ia:i' ou 'dir:i'
  String? _playing;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() { if (mounted) setState(() => _playing = null); });
    _tts.setErrorHandler((_) { if (mounted) setState(() => _playing = null); });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _ouvirIA(int i) async {
    final key = 'ia:$i';
    if (_playing == key) {
      await _tts.stop();
      setState(() => _playing = null);
      return;
    }
    if (_playing != null) await _tts.stop();

    if (_cacheIA.containsKey(i)) {
      setState(() => _playing = key);
      await _tts.speak(_cacheIA[i]!);
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

    setState(() => _carregandoIA[i] = true);
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
      _cacheIA[i] = txt;
      setState(() { _carregandoIA.remove(i); _playing = key; });
      await _tts.speak(txt);
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoIA.remove(i));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro IA: $e'), backgroundColor: red),
        );
      }
    }
  }

  Future<void> _ouvirPlanalto(int i) async {
    final key = 'dir:$i';
    if (_playing == key) {
      await _tts.stop();
      setState(() => _playing = null);
      return;
    }
    if (_playing != null) await _tts.stop();

    if (_cacheDir.containsKey(i)) {
      setState(() => _playing = key);
      await _tts.speak(_cacheDir[i]!);
      return;
    }

    setState(() => _carregandoDir[i] = true);
    final d = _bloco1[i];
    try {
      // Usa a função serverless Vercel (mesma origem do app web) — sem CORS
      final apiUrl = Uri.parse(
        'https://oab47pro.vercel.app/api/planalto?url=${Uri.encodeComponent(d.url)}',
      );
      final resp = await http.get(apiUrl)
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (json['error'] != null) throw Exception(json['error']);
      String txt = (json['txt'] as String? ?? '').trim();
      if (txt.length < 50) throw Exception('Conteúdo não encontrado');
      _cacheDir[i] = txt;
      setState(() { _carregandoDir.remove(i); _playing = key; });
      await _tts.speak(txt);
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoDir.remove(i));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro Planalto: $e'), backgroundColor: red),
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
          if (_playing != null)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: orange, size: 22),
              tooltip: 'Parar leitura',
              onPressed: () async { await _tts.stop(); setState(() => _playing = null); },
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _bloco1.length,
        itemBuilder: (_, i) {
          final d = _bloco1[i];
          final keyIA = 'ia:$i';
          final keyDir = 'dir:$i';
          final loadIA = _carregandoIA[i] == true;
          final loadDir = _carregandoDir[i] == true;
          final playIA = _playing == keyIA;
          final playDir = _playing == keyDir;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: navyLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (playIA || playDir) ? orange : navyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
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
                ]),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Botão IA
                    SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: (loadIA || loadDir) ? null : () => _ouvirIA(i),
                        icon: loadIA
                            ? const SizedBox(width: 13, height: 13,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: orange))
                            : Icon(playIA ? Icons.stop : Icons.smart_toy_outlined,
                                size: 14, color: playIA ? red : orange),
                        label: Text(
                          loadIA ? 'Carregando…' : (playIA ? 'Parar IA' : '🤖 Ouvir (IA)'),
                          style: TextStyle(color: playIA ? red : orange, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: playIA ? red : navyBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                    // Botão Planalto
                    SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: (loadIA || loadDir) ? null : () => _ouvirPlanalto(i),
                        icon: loadDir
                            ? const SizedBox(width: 13, height: 13,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: orange))
                            : Icon(playDir ? Icons.stop : Icons.menu_book_outlined,
                                size: 14, color: playDir ? red : orange),
                        label: Text(
                          loadDir ? 'Carregando…' : (playDir ? 'Parar' : '📖 Ouvir Planalto'),
                          style: TextStyle(color: playDir ? red : orange, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: playDir ? red : navyBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
