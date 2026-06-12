import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../config/supabase_config.dart';
import '../providers/app_provider.dart';
import '../services/gemini_service.dart';
import '../services/deepseek_service.dart';

class ResumosScreen extends StatefulWidget {
  const ResumosScreen({super.key});

  @override
  State<ResumosScreen> createState() => _ResumosScreenState();
}

class _AudioItem {
  final String nome;
  final String arquivo;
  final String url;
  const _AudioItem({required this.nome, required this.arquivo, required this.url});
}

class _ResumosScreenState extends State<ResumosScreen> {
  final FlutterTts _tts = FlutterTts();
  List<_AudioItem> _audios = [];
  bool _carregando = true;
  String? _erro;
  final Map<String, double> _progresso = {};
  bool _falando = false;

  // Atualizações legislativas IA
  bool _buscandoAtualizacoes = false;
  String? _resultadoAtualizacoes;
  String? _erroAtualizacoes;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('pt-BR');
    _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() { if (mounted) setState(() => _falando = false); });
    _tts.setErrorHandler((e) { if (mounted) setState(() => _falando = false); });
    _carregar();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final items = await _listarAudios();
      setState(() { _audios = items; _carregando = false; });
    } catch (e) {
      setState(() { _erro = e.toString(); _carregando = false; });
    }
  }

  Future<List<_AudioItem>> _listarAudios() async {
    final baseUrl = '$supabaseUrl/storage/v1/object/public/audios';
    final listUrl = '$supabaseUrl/storage/v1/object/list/audios';
    final resp = await http.post(
      Uri.parse(listUrl),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
      },
      body: '{"prefix":"","limit":200,"sortBy":{"column":"name","order":"asc"}}',
    );
    if (resp.statusCode != 200) {
      throw Exception('Bucket "audios" não encontrado.');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .where((i) => (i['name'] as String?)?.toLowerCase().endsWith('.mp3') == true && i['id'] != null)
        .map((i) {
          final name = i['name'] as String;
          return _AudioItem(
            nome: _formatar(name),
            arquivo: name,
            url: '$baseUrl/${Uri.encodeComponent(name)}',
          );
        })
        .toList();
  }

  String _formatar(String nome) =>
      nome.replaceAll('.mp3', '').replaceAll('_', ' ').replaceAll('-', ' ');

  Future<String?> _caminhoLocal(String arquivo) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/audios/$arquivo');
    return f.existsSync() ? f.path : null;
  }

  Future<void> _baixar(_AudioItem item) async {
    setState(() => _progresso[item.arquivo] = 0);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audiosDir = Directory('${dir.path}/audios');
      if (!audiosDir.existsSync()) audiosDir.createSync();
      final file = File('${audiosDir.path}/${item.arquivo}');
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(item.url));
      final resp = await client.send(req);
      final total = resp.contentLength ?? 1;
      int recebido = 0;
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        recebido += chunk.length;
        if (mounted) setState(() => _progresso[item.arquivo] = recebido / total);
      }
      await sink.close();
      client.close();
      if (mounted) {
        setState(() => _progresso.remove(item.arquivo));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download concluído: ${item.nome}'), backgroundColor: green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _progresso.remove(item.arquivo));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no download: $e'), backgroundColor: red),
        );
      }
    }
  }

  Future<void> _tocar(_AudioItem item) async {
    final local = await _caminhoLocal(item.arquivo);
    Uri uri;
    if (local != null) {
      uri = Uri.file(local);
    } else {
      uri = Uri.parse(item.url);
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum player de áudio encontrado')),
        );
      }
    }
  }

  Future<void> _falarTexto(String texto) async {
    if (_falando) {
      await _tts.stop();
      setState(() => _falando = false);
      return;
    }
    setState(() => _falando = true);
    await _tts.speak(texto);
  }

  Future<void> _buscarAtualizacoes() async {
    final app = context.read<AppProvider>();
    final cfg = app.estado.config;
    if (!cfg.temChave) {
      setState(() => _erroAtualizacoes = 'Configure uma chave de IA em Configurações.');
      return;
    }
    setState(() {
      _buscandoAtualizacoes = true;
      _resultadoAtualizacoes = null;
      _erroAtualizacoes = null;
    });
    final prompt = '''Disciplina: Resumos de Áudio — OAB 1ª Fase
Data de hoje: junho de 2026.

Liste as principais atualizações legislativas e jurisprudenciais de 2025-2026 relevantes para a OAB 1ª Fase. Inclua:
• Emendas Constitucionais, Leis Complementares ou Leis Ordinárias novas
• Súmulas vinculantes do STF ou STJ de 2024-2026
• Alterações em pontos clássicos cobrados pela FGV

Para cada item: "[Nº e nome da norma] — o que mudou e como impacta o candidato."
Máximo 250 palavras.''';
    try {
      String resultado;
      if (cfg.provedorAtivo == 'deepseek') {
        resultado = await DeepSeekService.generate(
          apiKey: cfg.deepseek,
          model: cfg.deepseekModelo,
          prompt: prompt,
          maxTokens: 1000,
        );
      } else {
        resultado = await GeminiService.generateWithSystem(
          apiKey: cfg.gemini,
          model: cfg.modelo,
          prompt: prompt,
          maxTokens: 1000,
        );
      }
      setState(() { _resultadoAtualizacoes = resultado; _buscandoAtualizacoes = false; });
    } catch (e) {
      setState(() { _erroAtualizacoes = e.toString(); _buscandoAtualizacoes = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.headphones_outlined, color: orange, size: 18),
          SizedBox(width: 8),
          Text('Resumos & Áudio'),
        ]),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined, size: 20), onPressed: _carregar),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: orange))
          : _erro != null
              ? _buildErro()
              : _buildConteudo(),
    );
  }

  Widget _buildConteudo() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Card de atualizações legislativas 2026
        _buildCardAtualizacoes(),
        const SizedBox(height: 12),
        // Info TTS
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: navyLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: navyBorder),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: textMuted, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _audios.isEmpty
                    ? 'Faça upload de MP3s no bucket "audios" do Supabase para ouvir aqui.'
                    : 'Baixe para ouvir offline com tela bloqueada. "Ouvir" abre no player do celular.',
                style: const TextStyle(color: textMuted, fontSize: 11),
              ),
            ),
          ]),
        ),
        if (_audios.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._audios.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildItem(e.value),
          )),
        ],
      ],
    );
  }

  Widget _buildCardAtualizacoes() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1200).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5C3D00).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('⚠', style: TextStyle(fontSize: 15)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Atualizações legislativas 2026 (IA)',
                  style: TextStyle(color: Color(0xFFFCD34D), fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _buscandoAtualizacoes ? null : _buscarAtualizacoes,
                icon: _buscandoAtualizacoes
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: orange))
                    : const Icon(Icons.search, size: 16, color: orange),
                label: Text(
                  _buscandoAtualizacoes ? 'Consultando IA…' : 'Pesquisar atualizações 2026',
                  style: const TextStyle(color: orange, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: navyBorder),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_resultadoAtualizacoes != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_falando ? Icons.stop : Icons.volume_up, size: 18, color: orange),
                tooltip: _falando ? 'Parar leitura' : 'Ouvir resultado',
                onPressed: () => _falarTexto(_resultadoAtualizacoes!),
              ),
            ],
          ]),
          if (_resultadoAtualizacoes != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: navyLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: navyBorder),
              ),
              child: Text(_resultadoAtualizacoes!,
                  style: const TextStyle(color: textPrimary, fontSize: 12, height: 1.6)),
            ),
          ],
          if (_erroAtualizacoes != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_erroAtualizacoes!, style: const TextStyle(color: red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(_AudioItem item) {
    final baixando = _progresso.containsKey(item.arquivo);
    final progresso = _progresso[item.arquivo];

    return FutureBuilder<String?>(
      future: _caminhoLocal(item.arquivo),
      builder: (_, snap) {
        final baixado = snap.data != null;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: navyLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: navyBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note, color: orange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.nome,
                            style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (baixado)
                          const Text('✓ Disponível offline',
                              style: TextStyle(color: green, fontSize: 10)),
                      ],
                    ),
                  ),
                  if (!baixando && !baixado)
                    IconButton(
                      icon: const Icon(Icons.download_outlined, size: 20, color: textMuted),
                      tooltip: 'Baixar para offline',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => _baixar(item),
                    ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _tocar(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow, color: Colors.white, size: 15),
                          const SizedBox(width: 4),
                          Text(baixado ? 'Ouvir (offline)' : 'Ouvir',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (baixando && progresso != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progresso,
                    backgroundColor: navyBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(orange),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${(progresso * 100).round()}% baixado',
                    style: const TextStyle(color: textMuted, fontSize: 10)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_outlined, color: textMuted, size: 48),
          const SizedBox(height: 16),
          const Text('Não foi possível carregar os áudios',
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_erro ?? '', style: const TextStyle(color: textMuted, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _carregar, child: const Text('Tentar novamente')),
        ]),
      ),
    );
  }
}
