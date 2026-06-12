import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../services/gemini_service.dart';
import '../services/deepseek_service.dart';

const _bloco1 = [
  _Disc('etica', 'Ética Profissional', [
    'Direitos e Prerrogativas do Advogado',
    'Infrações e Sanções Disciplinares',
    'Honorários Advocatícios',
    'Incompatibilidades e Impedimentos',
    'Sociedade de Advogados',
  ]),
  _Disc('constitucional', 'Direito Constitucional', [
    'Controle de Constitucionalidade',
    'Organização dos Poderes',
    'Direitos e Garantias Fundamentais',
    'Remédios Constitucionais',
    'Organização do Estado',
  ]),
  _Disc('administrativo', 'Direito Administrativo', [
    'Licitações e Contratos (Lei 14.133/21)',
    'Agentes Públicos',
    'Intervenção na Propriedade',
    'Atos Administrativos',
    'Responsabilidade Civil do Estado',
  ]),
  _Disc('civil', 'Direito Civil', [
    'Direito de Família',
    'Contratos em Espécie',
    'Direitos Reais',
    'Direito das Sucessões',
    'Parte Geral (Negócio Jurídico)',
  ]),
  _Disc('processo_civil', 'Direito Processual Civil', [
    'Sistema Recursal',
    'Procedimento Comum',
    'Execução e Cumprimento de Sentença',
    'Tutelas Provisórias',
    'Intervenção de Terceiros',
  ]),
  _Disc('penal', 'Direito Penal', [
    'Teoria do Crime',
    'Crimes contra o Patrimônio',
    'Crimes contra a Pessoa',
    'Teoria das Penas',
    'Crimes contra a Administração Pública',
  ]),
  _Disc('processo_penal', 'Direito Processual Penal', [
    'Recursos',
    'Inquérito Policial',
    'Provas',
    'Prisões e Medidas Cautelares',
    'Ação Penal',
  ]),
];

class _Disc {
  final String id, nome;
  final List<String> temas;
  const _Disc(this.id, this.nome, this.temas);
}

class LeisScreen extends StatefulWidget {
  const LeisScreen({super.key});

  @override
  State<LeisScreen> createState() => _LeisScreenState();
}

class _LeisScreenState extends State<LeisScreen> {
  final FlutterTts _tts = FlutterTts();
  int _discIdx = 0;
  bool _falando = false;
  // cacheKey → texto
  final Map<String, String> _cache = {};
  // cacheKey → carregando
  final Map<String, bool> _carregando = {};
  // cacheKey → expandido
  final Map<String, bool> _expandido = {};

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('pt-BR');
    _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() { if (mounted) setState(() => _falando = false); });
    _tts.setErrorHandler((_) { if (mounted) setState(() => _falando = false); });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String _cacheKey(String discId, String tema) => 'lei_${discId}_$tema';

  Future<String?> _buscarArtigos(String discId, String discNome, String tema) async {
    final key = _cacheKey(discId, tema);
    if (_cache.containsKey(key)) return _cache[key];
    final app = context.read<AppProvider>();
    final cfg = app.estado.config;
    if (!cfg.temChave) return null;
    setState(() => _carregando[key] = true);
    final prompt = '''Você é um professor de Direito para concurso OAB 1ª Fase.
Disciplina: $discNome
Tema: $tema

Transcreva e explique os artigos legais mais importantes sobre este tema que são cobrados no Exame de Ordem.
Cite os artigos exatos (número e texto resumido) da lei vigente.
NUNCA invente artigos. Seja preciso, direto e objetivo.
Máximo 350 palavras.''';
    try {
      final String txt;
      if (cfg.provedorAtivo == 'deepseek') {
        txt = await DeepSeekService.generate(
          apiKey: cfg.deepseek, model: cfg.deepseekModelo,
          prompt: prompt, maxTokens: 800,
        );
      } else {
        txt = await GeminiService.generateWithSystem(
          apiKey: cfg.gemini, model: cfg.modelo,
          prompt: prompt, maxTokens: 800,
        );
      }
      _cache[key] = txt;
      return txt;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro IA: $e'), backgroundColor: red),
      );
      return null;
    } finally {
      if (mounted) setState(() => _carregando.remove(key));
    }
  }

  Future<void> _ouvir(String discId, String discNome, String tema) async {
    if (_falando) { await _tts.stop(); setState(() => _falando = false); return; }
    final txt = await _buscarArtigos(discId, discNome, tema);
    if (txt == null) return;
    setState(() => _falando = true);
    await _tts.speak(txt);
  }

  @override
  Widget build(BuildContext context) {
    final disc = _bloco1[_discIdx];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.menu_book_outlined, color: orange, size: 18),
          SizedBox(width: 8),
          Text('Leitura de Leis'),
        ]),
        automaticallyImplyLeading: false,
        actions: [
          if (_falando)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: orange, size: 22),
              tooltip: 'Parar leitura',
              onPressed: () async { await _tts.stop(); setState(() => _falando = false); },
            ),
        ],
      ),
      body: Column(
        children: [
          // Seletor de disciplina
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: DropdownButtonFormField<int>(
              value: _discIdx,
              dropdownColor: navyLight,
              style: const TextStyle(color: textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Disciplina (Bloco 1)',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _bloco1.asMap().entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value.nome, style: const TextStyle(color: textPrimary, fontSize: 13)),
              )).toList(),
              onChanged: (v) { if (v != null) setState(() => _discIdx = v); },
            ),
          ),
          const SizedBox(height: 8),
          // Lista de temas
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: disc.temas.length,
              itemBuilder: (_, i) {
                final tema = disc.temas[i];
                final key = _cacheKey(disc.id, tema);
                final carregando = _carregando[key] == true;
                final texto = _cache[key];
                final expandido = _expandido[key] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: navyLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: navyBorder),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                      child: Row(children: [
                        Container(
                          width: 22, height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(6)),
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(tema,
                          style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: carregando ? null : () => _ouvir(disc.id, disc.nome, tema),
                            icon: carregando
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: orange))
                                : Icon(_falando ? Icons.stop : Icons.volume_up, size: 16, color: orange),
                            label: Text(
                              carregando ? 'Consultando IA…' : '🔊 Ouvir artigo (Planalto)',
                              style: const TextStyle(color: orange, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: navyBorder),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: carregando ? null : () async {
                            if (expandido) {
                              setState(() => _expandido[key] = false);
                              return;
                            }
                            final txt = await _buscarArtigos(disc.id, disc.nome, tema);
                            if (txt != null) setState(() => _expandido[key] = true);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: navyBorder),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          child: Text(expandido ? 'Fechar' : '📋 Ler',
                              style: const TextStyle(color: textSecondary, fontSize: 12)),
                        ),
                      ]),
                    ),
                    if (expandido && texto != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: navy,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: navyBorder),
                        ),
                        child: Text(texto,
                          style: const TextStyle(color: textPrimary, fontSize: 12, height: 1.6)),
                      ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
