import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../config/supabase_config.dart';

class BibliotecaScreen extends StatefulWidget {
  const BibliotecaScreen({super.key});

  @override
  State<BibliotecaScreen> createState() => _BibliotecaScreenState();
}

class _BibliotecaScreenState extends State<BibliotecaScreen> {
  Map<String, Map<String, List<_PdfItem>>> _arvore = {};
  bool _carregando = true;
  String? _erro;
  final Set<String> _abertos = {'bloco1'};

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

  Future<Map<String, Map<String, List<_PdfItem>>>> _construirArvore() async {
    const baseUrl = '$supabaseUrl/storage/v1/object/public/pdfs';
    // Tenta index.json primeiro
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
            arvore[bloco]![pasta] = arquivos.map((nome) => _PdfItem(
              nome: nome,
              url: '$prefixo${Uri.encodeComponent(nome)}',
            )).toList();
          }
        }
        return arvore;
      }
    } catch (_) {}

    // Fallback: listar via API
    return await _listarViaApi(baseUrl);
  }

  Future<Map<String, Map<String, List<_PdfItem>>>> _listarViaApi(String baseUrl) async {
    final blocos = ['bloco1', 'bloco2', 'bloco3', 'provas'];
    final arvore = <String, Map<String, List<_PdfItem>>>{};
    final listUrl = '$supabaseUrl/storage/v1/object/list/pdfs';

    for (final bloco in blocos) {
      final r = await http.post(
        Uri.parse(listUrl),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'prefix': bloco, 'limit': 1000, 'sortBy': {'column': 'name', 'order': 'asc'}}),
      );
      if (r.statusCode != 200) continue;
      final items = jsonDecode(r.body) as List<dynamic>;
      if (items.isEmpty) continue;

      final struct = <String, List<_PdfItem>>{};
      final raiz = items.where((i) => i['id'] != null && (i['name'] as String).toLowerCase().endsWith('.pdf')).toList();
      if (raiz.isNotEmpty) {
        struct['_raiz'] = raiz.map((i) {
          final name = i['name'] as String;
          return _PdfItem(nome: name, url: '$baseUrl/$bloco/${Uri.encodeComponent(name)}');
        }).toList();
      }

      for (final pasta in items.where((i) => i['id'] == null)) {
        final pastaNome = pasta['name'] as String;
        final r2 = await http.post(
          Uri.parse(listUrl),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'prefix': '$bloco/$pastaNome', 'limit': 1000, 'sortBy': {'column': 'name', 'order': 'asc'}}),
        );
        if (r2.statusCode != 200) continue;
        final pdfs = (jsonDecode(r2.body) as List<dynamic>)
            .where((i) => i['id'] != null && (i['name'] as String).toLowerCase().endsWith('.pdf'))
            .map((i) {
              final name = i['name'] as String;
              return _PdfItem(nome: name, url: '$baseUrl/$bloco/${Uri.encodeComponent(pastaNome)}/${Uri.encodeComponent(name)}');
            })
            .toList();
        if (pdfs.isNotEmpty) struct[pastaNome] = pdfs;
      }
      if (struct.isNotEmpty) arvore[bloco] = struct;
    }

    if (arvore.isEmpty) throw Exception('Nenhum PDF encontrado no bucket "pdfs".');
    return arvore;
  }

  Future<void> _abrirPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o PDF')),
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
          : _erro != null
              ? _buildErro()
              : _arvore.isEmpty
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
          const Text('Não foi possível carregar a biblioteca',
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_erro ?? '', style: const TextStyle(color: textMuted, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text(
            'Para disponibilizar os PDFs:\n'
            '1. No Supabase, crie o bucket "pdfs" (Public)\n'
            '2. Faça upload com a estrutura:\n'
            '   bloco1/Disciplina/arquivo.pdf\n'
            '   bloco2/Disciplina/arquivo.pdf',
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
          Icon(Icons.picture_as_pdf_outlined, color: textMuted, size: 48),
          SizedBox(height: 16),
          Text('Nenhum PDF disponível',
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text(
            'Faça upload dos PDFs no bucket "pdfs"\ndo Supabase Storage para acessá-los aqui.',
            style: TextStyle(color: textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
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
          decoration: BoxDecoration(
            color: navyLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: navyBorder),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() {
                  if (aberto) { _abertos.remove(bloco); } else { _abertos.add(bloco); }
                }),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_rotuloBloco[bloco] ?? bloco,
                                style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('$total PDFs',
                                style: const TextStyle(color: textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(aberto ? Icons.expand_less : Icons.expand_more, color: textMuted, size: 20),
                    ],
                  ),
                ),
              ),
              if (aberto)
                ...pastas.entries.map((pastaEntry) {
                  final pasta = pastaEntry.key;
                  final arquivos = pastaEntry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                        color: navy,
                        child: Text(
                          pasta == '_raiz' ? 'Arquivos gerais' : pasta,
                          style: const TextStyle(color: orange, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      ...arquivos.map((pdf) => InkWell(
                        onTap: () => _abrirPdf(pdf.url),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf, color: red, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(pdf.nome,
                                    style: const TextStyle(color: textPrimary, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const Icon(Icons.open_in_new, color: textMuted, size: 14),
                            ],
                          ),
                        ),
                      )),
                    ],
                  );
                }),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PdfItem {
  final String nome;
  final String url;
  const _PdfItem({required this.nome, required this.url});
}
