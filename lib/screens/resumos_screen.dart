import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../config/supabase_config.dart';

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
  List<_AudioItem> _audios = [];
  bool _carregando = true;
  String? _erro;
  final Map<String, double> _progresso = {};

  @override
  void initState() {
    super.initState();
    _carregar();
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
      throw Exception('Bucket "audios" não encontrado. Crie-o no Supabase Storage e faça upload dos MP3s.');
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

  String _formatar(String nome) {
    return nome.replaceAll('.mp3', '').replaceAll('_', ' ').replaceAll('-', ' ');
  }

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
          const SnackBar(content: Text('Nenhum player de áudio encontrado no dispositivo')),
        );
      }
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
              : _audios.isEmpty
                  ? _buildVazio()
                  : _buildLista(),
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
          const Text(
            'Para disponibilizar os áudios:\n'
            '1. Crie o bucket "audios" no Supabase Storage\n'
            '2. Faça upload dos arquivos MP3',
            style: TextStyle(color: textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _carregar, child: const Text('Tentar novamente')),
        ]),
      ),
    );
  }

  Widget _buildVazio() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.music_off_outlined, color: textMuted, size: 48),
          SizedBox(height: 16),
          Text('Nenhum áudio disponível',
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text(
            'Faça upload de arquivos MP3 para o\nbucket "audios" no Supabase Storage.',
            style: TextStyle(color: textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  Widget _buildLista() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: navy,
          child: const Row(children: [
            Icon(Icons.info_outline, color: textMuted, size: 14),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Baixe para ouvir offline com tela bloqueada. "Ouvir" abre no player do celular.',
                style: TextStyle(color: textMuted, fontSize: 11),
              ),
            ),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _audios.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildItem(_audios[i]),
          ),
        ),
      ],
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
                  const Icon(Icons.music_note, color: orange, size: 20),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow, color: Colors.white, size: 16),
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
}
