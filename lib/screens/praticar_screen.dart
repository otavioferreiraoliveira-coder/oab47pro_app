import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/questao.dart';
import '../providers/app_provider.dart';
import '../services/gemini_service.dart';

class PraticarScreen extends StatefulWidget {
  const PraticarScreen({super.key});

  @override
  State<PraticarScreen> createState() => _PraticarScreenState();
}

class _PraticarScreenState extends State<PraticarScreen> {
  // Filtros
  int? _bloco;
  String? _disciplina;
  String? _status;
  String _busca = '';

  // Questão atual
  List<Questao> _lista = [];
  int _idx = 0;
  String? _resposta;
  bool _mostrou = false;
  String? _explicacao;
  bool _carregandoIA = false;

  final _buscaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _atualizar());
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _atualizar() {
    final app = context.read<AppProvider>();
    setState(() {
      _lista = app.filtrar(
          bloco: _bloco,
          disciplina: _disciplina,
          status: _status,
          busca: _busca,
          semAnuladas: true);
      _lista.shuffle();
      _idx = 0;
      _resposta = null;
      _mostrou = false;
      _explicacao = null;
    });
  }

  void _responder(String alt) {
    if (_mostrou) return;
    final q = _lista[_idx];
    final ok = alt == q.gabarito;
    setState(() {
      _resposta = alt;
      _mostrou = true;
    });
    context.read<AppProvider>().responder(q.id, alt, ok);
  }

  void _proxima() {
    setState(() {
      _idx = (_idx + 1) % _lista.length;
      _resposta = null;
      _mostrou = false;
      _explicacao = null;
    });
  }

  Future<void> _explicar() async {
    final app = context.read<AppProvider>();
    final q = _lista[_idx];
    final cacheKey = 'exp_${q.id}';
    if (app.estado.cacheIA.containsKey(cacheKey)) {
      setState(() => _explicacao = app.estado.cacheIA[cacheKey]);
      return;
    }
    final apiKey = app.estado.config.gemini;
    final model = app.estado.config.modelo;
    if (apiKey.isEmpty) {
      setState(() => _explicacao =
          'Configure sua chave Gemini em Configurações para usar esta função.');
      return;
    }
    setState(() => _carregandoIA = true);
    try {
      final opcTxt = q.opcoes.entries.map((e) => '${e.key}) ${e.value}').join('\n');
      final prompt =
          'Explique de forma didática e objetiva (máx 200 palavras) por que a alternativa ${q.gabarito} é o gabarito correto da seguinte questão do Exame OAB:\n\n${q.enunciado}\n\n$opcTxt\n\nGabarito: ${q.gabarito}';
      final resp = await GeminiService.generate(
          apiKey: apiKey, model: model, prompt: prompt);
      app.estado.cacheIA[cacheKey] = resp;
      app.sincronizar();
      setState(() => _explicacao = resp);
    } catch (e) {
      setState(() => _explicacao = 'Erro: $e');
    } finally {
      setState(() => _carregandoIA = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (!app.carregado) {
      return const Center(child: CircularProgressIndicator(color: orange));
    }

    return Scaffold(
      body: Column(
        children: [
          // Filtros
          _buildFiltros(app),
          const Divider(height: 1),

          if (_lista.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Nenhuma questão encontrada.',
                    style: TextStyle(color: textSecondary)),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Contador
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_idx + 1} / ${_lista.length}',
                          style: const TextStyle(
                              color: textMuted, fontSize: 12)),
                      _buildBlocoBadge(_lista[_idx]),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Enunciado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: navyLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: navyBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exame ${_lista[_idx].exame} · ${app.disciplinas[_lista[_idx].disciplina] ?? _lista[_idx].disciplina}',
                          style: const TextStyle(
                              color: orange, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Text(_lista[_idx].enunciado,
                            style: const TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                height: 1.55)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Opções
                  ..._lista[_idx].opcoes.entries.map((e) =>
                      _buildOpcao(e.key, e.value, _lista[_idx].gabarito)),

                  // Feedback
                  if (_mostrou) ...[
                    const SizedBox(height: 12),
                    _buildFeedback(),
                  ],

                  // Botão próxima
                  if (_mostrou) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _carregandoIA ? null : _explicar,
                            icon: _carregandoIA
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5, color: orange))
                                : const Icon(Icons.auto_awesome,
                                    size: 16, color: orange),
                            label: const Text('Explicar',
                                style: TextStyle(color: orange)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: navyBorder),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _proxima,
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('Próxima'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Explicação IA
                  if (_explicacao != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: orange.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.auto_awesome,
                                size: 14, color: orange),
                            SizedBox(width: 6),
                            Text('Explicação IA',
                                style: TextStyle(
                                    color: orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 8),
                          Text(_explicacao!,
                              style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltros(AppProvider app) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: navy,
      child: Column(
        children: [
          // Busca
          SizedBox(
            height: 38,
            child: TextField(
              controller: _buscaCtrl,
              onChanged: (v) {
                _busca = v;
                _atualizar();
              },
              style: const TextStyle(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar questão…',
                prefixIcon:
                    const Icon(Icons.search, size: 16, color: textMuted),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
                suffixIcon: _busca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: textMuted),
                        onPressed: () {
                          _buscaCtrl.clear();
                          _busca = '';
                          _atualizar();
                        })
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Todos', _bloco == null && _disciplina == null,
                    () {
                  _bloco = null;
                  _disciplina = null;
                  _atualizar();
                }),
                const SizedBox(width: 6),
                ...[1, 2, 3].map((b) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _filterChip('Bloco $b', _bloco == b, () {
                        _bloco = _bloco == b ? null : b;
                        _disciplina = null;
                        _atualizar();
                      }),
                    )),
                const SizedBox(width: 6),
                _filterChip(
                    'Não respondidas',
                    _status == 'nao',
                    () => setState(() {
                          _status = _status == 'nao' ? null : 'nao';
                          _atualizar();
                        })),
                const SizedBox(width: 6),
                _filterChip(
                    'Erradas',
                    _status == 'erradas',
                    () => setState(() {
                          _status = _status == 'erradas' ? null : 'erradas';
                          _atualizar();
                        })),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? orange : navyBorder,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildOpcao(String letra, String texto, String gabarito) {
    Color bg = navyLight;
    Color border = navyBorder;
    Color textColor = textPrimary;

    if (_mostrou) {
      if (letra == gabarito) {
        bg = green.withValues(alpha: 0.12);
        border = green.withValues(alpha: 0.5);
      } else if (letra == _resposta && letra != gabarito) {
        bg = red.withValues(alpha: 0.12);
        border = red.withValues(alpha: 0.5);
        textColor = red;
      } else {
        textColor = textMuted;
      }
    } else if (_resposta == letra) {
      bg = orange.withValues(alpha: 0.1);
      border = orange;
    }

    return GestureDetector(
      onTap: () => _responder(letra),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _mostrou && letra == gabarito
                    ? green
                    : (_mostrou && letra == _resposta && letra != gabarito
                        ? red
                        : navyBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(letra,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texto,
                  style:
                      TextStyle(color: textColor, fontSize: 13, height: 1.4)),
            ),
            if (_mostrou && letra == gabarito)
              const Icon(Icons.check_circle, color: green, size: 18),
            if (_mostrou && letra == _resposta && letra != gabarito)
              const Icon(Icons.cancel, color: red, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final q = _lista[_idx];
    final ok = _resposta == q.gabarito;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok
            ? green.withValues(alpha: 0.1)
            : red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: ok
                ? green.withValues(alpha: 0.4)
                : red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel,
              color: ok ? green : red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? 'Correto! Alternativa ${q.gabarito}.'
                  : 'Incorreto. Gabarito: ${q.gabarito}.',
              style: TextStyle(
                  color: ok ? green : red,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocoBadge(Questao q) {
    final cores = {1: const Color(0xFF3B82F6), 2: orange, 3: green};
    final c = cores[q.bloco] ?? textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text('Bloco ${q.bloco}',
          style: TextStyle(color: c, fontSize: 11)),
    );
  }
}
