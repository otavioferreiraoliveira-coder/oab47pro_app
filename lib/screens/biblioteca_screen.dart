import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/theme.dart';
import '../config/supabase_config.dart';

class BibliotecaScreen extends StatefulWidget {
  const BibliotecaScreen({super.key});

  @override
  State<BibliotecaScreen> createState() => _BibliotecaScreenState();
}

class _PdfItem {
  final String nome;
  final String url;
  const _PdfItem({required this.nome, required this.url});
}

class _BibliotecaScreenState extends State<BibliotecaScreen> {
  Map<String, Map<String, List<_PdfItem>>> _arvore = {};
  bool _carregando = true;
  String? _erro;
  final Set<String> _abertos = {'bloco1'};
  final Map<String, double> _baixando = {};

  static const _rotuloBloco = {
    'bloco1': '📕 BLOCO 1 — Prioritário',
    'bloco2': '📗 BLOCO 2',
    'bloco3': '📘 BLOCO 3',
    'provas': '📂 Provas anteriores',
  };

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final arvore = await _construirArvore();
      setState(() { _arvore = arvore; _carregando = false; });
    } catch (e) {
      setState(() { _erro = e.toString(); _carregando = false; });
    }
  }

  // Natural sort: "2 - X" antes de "10 - X"
  List<_PdfItem> _sortNatural(List<_PdfItem> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final na = a.nome.replaceFirstMapped(RegExp(r'^(\d+)'), (m) => m[0]!.padLeft(6, '0'));
      final nb = b.nome.replaceFirstMapped(RegExp(r'^(\d+)'), (m) => m[0]!.padLeft(6, '0'));
      return na.compareTo(nb);
    });
    return sorted;
  }

  Future<Map<String, Map<String, List<_PdfItem>>>> _construirArvore() async {
    const baseUrl = '$supabaseUrl/storage/v1/object/public/pdfs';
    try {
      final r = await http.get(Uri.parse('$baseUrl/index.json'));
      if (r.statusCode == 200) {
        final manifesto = jsonDecode(r.body) as Map<String, dynamic>;
        final arvore = <String, Map<String, List<_PdfItem>>>{};
        for (final entry in manifesto.entries) {
          final bloco = entry.key;
          final pastas = entry.value as Map<String, dynamic>;
          arvore[bloco] = {};
          for (final p in pastas.entries) {
            final pasta = p.key;
            final arquivos = (p.value as List<dynamic>).cast<String>();
            final prefixo = pasta == '_raiz' ? '$baseUrl/$bloco/' : '$baseUrl/$bloco/${Uri.encodeComponent(pasta)}/';
            final items = arquivos.map((nome) => _PdfItem(nome: nome, url: '$prefixo${Uri.encodeComponent(nome)}')).toList();
            arvore[bloco]![pasta] = _sortNatural(items);
          }
        }
        return arvore;
      }
    } catch (_) {}
    return await _listarViaApi(baseUrl);
  }

  Future<Map<String, Map<String, List<_PdfItem>>>> _listarViaApi(String baseUrl) async {
    final blocos = ['bloco1', 'bloco2', 'bloco3', 'provas'];
    final arvore = <String, Map<String, List<_PdfItem>>>{};
    final listUrl = '$supabaseUrl/storage/v1/object/list/pdfs';

    for (final bloco in blocos) {
      final r = await http.post(Uri.parse(listUrl),
        headers: {'apikey': supabaseAnonKey, 'Authorization': 'Bearer $supabaseAnonKey', 'Content-Type': 'application/json'},
        body: jsonEncode({'prefix': bloco, 'limit': 1000, 'sortBy': {'column': 'name', 'order': 'asc'}}));
      if (r.statusCode != 200) continue;
      final items = jsonDecode(r.body) as List<dynamic>;
      if (items.isEmpty) continue;

      final struct = <String, List<_PdfItem>>{};
      final raiz = items.where((i) => i['id'] != null && (i['name'] as String).toLowerCase().endsWith('.pdf')).toList();
      if (raiz.isNotEmpty) {
        struct['_raiz'] = _sortNatural(raiz.map((i) {
          final name = i['name'] as String;
          return _PdfItem(nome: name, url: '$baseUrl/$bloco/${Uri.encodeComponent(name)}');
        }).toList());
      }

      for (final pasta in items.where((i) => i['id'] == null)) {
        final pastaNome = pasta['name'] as String;
        final r2 = await http.post(Uri.parse(listUrl),
          headers: {'apikey': supabaseAnonKey, 'Authorization': 'Bearer $supabaseAnonKey', 'Content-Type': 'application/json'},
          body: jsonEncode({'prefix': '$bloco/$pastaNome', 'limit': 1000, 'sortBy': {'column': 'name', 'order': 'asc'}}));
        if (r2.statusCode != 200) continue;
        final pdfs = (jsonDecode(r2.body) as List<dynamic>)
            .where((i) => i['id'] != null && (i['name'] as String).toLowerCase().endsWith('.pdf'))
            .map((i) {
              final name = i['name'] as String;
              return _PdfItem(nome: name, url: '$baseUrl/$bloco/${Uri.encodeComponent(pastaNome)}/${Uri.encodeComponent(name)}');
            }).toList();
        if (pdfs.isNotEmpty) struct[pastaNome] = _sortNatural(pdfs);
      }
      if (struct.isNotEmpty) arvore[bloco] = struct;
    }

    if (arvore.isEmpty) throw Exception('Nenhum PDF encontrado no bucket "pdfs".');
    return arvore;
  }

  Future<String> _caminhoLocal(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final nome = Uri.parse(url).pathSegments.last;
    return '${dir.path}/pdfs/$nome';
  }

  Future<bool> _jaDownloadado(String url) async {
    final path = await _caminhoLocal(url);
    return File(path).existsSync();
  }

  Future<void> _abrirPdf(_PdfItem item) async {
    final localPath = await _caminhoLocal(item.url);
    final file = File(localPath);

    if (!file.existsSync()) {
      // Baixar primeiro
      await _downloadPdf(item);
      if (!File(localPath).existsSync()) return;
    }

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PdfViewerScreen(titulo: item.nome, caminhoLocal: localPath),
    ));
  }

  Future<void> _downloadPdf(_PdfItem item) async {
    final key = item.url;
    setState(() => _baixando[key] = 0);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pdfsDir = Directory('${dir.path}/pdfs');
      if (!pdfsDir.existsSync()) pdfsDir.createSync(recursive: true);
      final localPath = await _caminhoLocal(item.url);
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(item.url));
      final resp = await client.send(req);
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final total = resp.contentLength ?? 1;
      int recebido = 0;
      final sink = File(localPath).openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        recebido += chunk.length;
        if (mounted) setState(() => _baixando[key] = recebido / total);
      }
      await sink.close();
      client.close();
      if (mounted) setState(() => _baixando.remove(key));
    } catch (e) {
      if (mounted) {
        setState(() => _baixando.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.library_books_outlined, color: orange, size: 18),
          SizedBox(width: 8),
          Text('Biblioteca PDFs'),
        ]),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined, size: 20), onPressed: _carregar),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: orange))
          : _erro != null ? _buildErro() : _arvore.isEmpty ? _buildVazio() : _buildLista(),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_outlined, color: textMuted, size: 48),
          const SizedBox(height: 16),
          const Text('Não foi possível carregar a biblioteca',
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_erro ?? '', style: const TextStyle(color: textMuted, fontSize: 12), textAlign: TextAlign.center),
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
          Icon(Icons.picture_as_pdf_outlined, color: textMuted, size: 48),
          SizedBox(height: 16),
          Text('Nenhum PDF disponível', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Faça upload no bucket "pdfs" do Supabase Storage.',
              style: TextStyle(color: textSecondary, fontSize: 12), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildLista() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _arvore.entries.map((blocoEntry) {
        final bloco = blocoEntry.key;
        final pastas = blocoEntry.value;
        final total = pastas.values.fold(0, (s, l) => s + l.length);
        final aberto = _abertos.contains(bloco);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: navyLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: navyBorder)),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() { if (aberto) _abertos.remove(bloco); else _abertos.add(bloco); }),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_rotuloBloco[bloco] ?? bloco,
                          style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('$total PDFs', style: const TextStyle(color: textMuted, fontSize: 11)),
                    ])),
                    Icon(aberto ? Icons.expand_less : Icons.expand_more, color: textMuted, size: 20),
                  ]),
                ),
              ),
              if (aberto)
                ...pastas.entries.map((pastaEntry) {
                  final pasta = pastaEntry.key;
                  final arquivos = pastaEntry.value;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                      color: navy,
                      child: Text(pasta == '_raiz' ? 'Arquivos gerais' : pasta,
                          style: const TextStyle(color: orange, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    ...arquivos.map((pdf) => _buildPdfItem(pdf)),
                  ]);
                }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPdfItem(_PdfItem pdf) {
    final key = pdf.url;
    final baixandoAgora = _baixando.containsKey(key);
    final prog = _baixando[key];

    return FutureBuilder<bool>(
      future: _jaDownloadado(pdf.url),
      builder: (_, snap) {
        final salvo = snap.data == true;
        return InkWell(
          onTap: baixandoAgora ? null : () => _abrirPdf(pdf),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(salvo ? Icons.picture_as_pdf : Icons.picture_as_pdf_outlined,
                    color: salvo ? orange : red, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(pdf.nome.replaceAll('.pdf', '').replaceAll('.PDF', ''),
                      style: const TextStyle(color: textPrimary, fontSize: 12),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (salvo)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.check_circle, color: green, size: 14),
                  )
                else if (!baixandoAgora)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.open_in_new, color: textMuted, size: 14),
                  ),
              ]),
              if (salvo)
                const Text('Salvo no app', style: TextStyle(color: green, fontSize: 10)),
              if (baixandoAgora && prog != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: prog, minHeight: 3,
                    backgroundColor: navyBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(orange),
                  ),
                ),
                Text('${(prog * 100).round()}% baixando…',
                    style: const TextStyle(color: textMuted, fontSize: 10)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

// Tela de visualização de PDF in-app
class _PdfViewerScreen extends StatefulWidget {
  final String titulo;
  final String caminhoLocal;
  const _PdfViewerScreen({required this.titulo, required this.caminhoLocal});

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  int _paginas = 0;
  int _paginaAtual = 0;
  bool _carregando = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        title: Text(widget.titulo.replaceAll('.pdf', ''), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_paginas > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${_paginaAtual + 1}/$_paginas',
                    style: const TextStyle(color: textSecondary, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.caminhoLocal,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            nightMode: true,
            onRender: (pages) => setState(() { _paginas = pages ?? 0; _carregando = false; }),
            onPageChanged: (page, _) => setState(() => _paginaAtual = page ?? 0),
            onError: (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao abrir PDF: $e'), backgroundColor: red),
              );
              Navigator.pop(context);
            },
          ),
          if (_carregando)
            const Center(child: CircularProgressIndicator(color: orange)),
        ],
      ),
    );
  }
}
