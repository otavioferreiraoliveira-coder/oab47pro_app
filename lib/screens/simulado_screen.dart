import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/questao.dart';
import '../models/estado.dart';
import '../providers/app_provider.dart';

enum SimuladoFase { inicio, andamento, resultado }

class SimuladoScreen extends StatefulWidget {
  const SimuladoScreen({super.key});

  @override
  State<SimuladoScreen> createState() => _SimuladoScreenState();
}

class _SimuladoScreenState extends State<SimuladoScreen> {
  SimuladoFase _fase = SimuladoFase.inicio;
  String _tipo = 'completo';
  List<Questao> _questoes = [];
  final Map<int, String> _respostas = {};
  int _idx = 0;
  int _segundos = 0;
  Timer? _timer;
  SimuladoResult? _resultado;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciar(String tipo) {
    final app = context.read<AppProvider>();
    List<Questao> pool = app.questoes.where((q) => !q.anulada).toList();
    pool.shuffle();

    int total;
    if (tipo == 'completo') {
      total = 80;
    } else {
      final bloco = int.tryParse(tipo.replaceAll('bloco', '')) ?? 1;
      pool = pool.where((q) => q.bloco == bloco).toList();
      total = 40;
    }
    pool = pool.take(total).toList();

    setState(() {
      _tipo = tipo;
      _questoes = pool;
      _respostas.clear();
      _idx = 0;
      _segundos = tipo == 'completo' ? 18000 : 9000; // 5h ou 2.5h
      _fase = SimuladoFase.andamento;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_segundos > 0) {
          _segundos--;
        } else {
          _encerrar();
        }
      });
    });
  }

  void _encerrar() {
    _timer?.cancel();
    final app = context.read<AppProvider>();
    int ok = 0;
    final porDisc = <String, Map<String, int>>{};

    for (int i = 0; i < _questoes.length; i++) {
      final q = _questoes[i];
      final resp = _respostas[i];
      final acertou = resp == q.gabarito;
      if (acertou) ok++;
      porDisc.putIfAbsent(q.disciplina, () => {'ok': 0, 'total': 0});
      porDisc[q.disciplina]!['total'] = porDisc[q.disciplina]!['total']! + 1;
      if (acertou) {
        porDisc[q.disciplina]!['ok'] = porDisc[q.disciplina]!['ok']! + 1;
      }
      if (resp != null) {
        app.responder(q.id, resp, acertou, modo: 'simulado');
      }
    }

    final duracaoTotal = _tipo == 'completo' ? 18000 : 9000;
    final resultado = SimuladoResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ts: DateTime.now().millisecondsSinceEpoch,
      tipo: _tipo,
      nota: ok,
      total: _questoes.length,
      duracao: duracaoTotal - _segundos,
      porDisc: porDisc,
    );
    app.salvarSimulado(resultado);

    setState(() {
      _resultado = resultado;
      _fase = SimuladoFase.resultado;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_fase) {
        SimuladoFase.inicio => _buildInicio(),
        SimuladoFase.andamento => _buildAndamento(),
        SimuladoFase.resultado => _buildResultado(),
      },
    );
  }

  Widget _buildInicio() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Simulados',
            style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Pratique em condições de prova real.',
            style: TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        _simCard(
          'Simulado Completo',
          '80 questões · 5 horas',
          'Distribuição FGV — todos os blocos',
          Icons.article_outlined,
          () => _iniciar('completo'),
        ),
        const SizedBox(height: 10),
        _simCard(
          'Bloco 1',
          '40 questões · 2h30',
          'Direito Constitucional, Adm, Trabalho…',
          Icons.looks_one_outlined,
          () => _iniciar('bloco1'),
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 10),
        _simCard(
          'Bloco 2',
          '40 questões · 2h30',
          'Civil, Empresarial, Tributário…',
          Icons.looks_two_outlined,
          () => _iniciar('bloco2'),
          color: orange,
        ),
        const SizedBox(height: 10),
        _simCard(
          'Bloco 3',
          '40 questões · 2h30',
          'Processo Civil, Penal, Processo Penal…',
          Icons.looks_3_outlined,
          () => _iniciar('bloco3'),
          color: green,
        ),
        const SizedBox(height: 20),
        _buildHistorico(),
      ],
    );
  }

  Widget _simCard(String titulo, String sub, String desc, IconData icon,
      VoidCallback onTap,
      {Color color = orange}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: navyLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: navyBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text(sub,
                      style: TextStyle(color: color, fontSize: 12)),
                  Text(desc,
                      style: const TextStyle(
                          color: textMuted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorico() {
    final sims = context.watch<AppProvider>().estado.simulados.reversed.take(5).toList();
    if (sims.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Histórico',
            style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...sims.map((s) {
          final pct = s.percentual;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: navyLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: navyBorder),
            ),
            child: Row(
              children: [
                Icon(
                    pct >= 0.5
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: pct >= 0.5 ? green : red,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.nota}/${s.total} · ${(pct * 100).round()}%',
                          style: const TextStyle(
                              color: textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(
                          _formatDate(DateTime.fromMillisecondsSinceEpoch(s.ts)),
                          style: const TextStyle(
                              color: textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (pct >= 0.5 ? green : red)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s.tipo,
                      style: TextStyle(
                          color: pct >= 0.5 ? green : red,
                          fontSize: 11)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAndamento() {
    if (_questoes.isEmpty) return const SizedBox.shrink();
    final q = _questoes[_idx];
    final h = _segundos ~/ 3600;
    final m = (_segundos % 3600) ~/ 60;
    final s = _segundos % 60;
    final respondidas = _respostas.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_idx + 1}/${_questoes.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmarEncerrar(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (_segundos < 300 ? red : navyBorder)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _segundos < 300 ? red : navyBorder),
              ),
              child: Text(
                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                style: TextStyle(
                    color: _segundos < 300 ? red : textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_idx + 1) / _questoes.length,
            backgroundColor: navyBorder,
            color: orange,
            minHeight: 3,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: navyLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: navyBorder),
                  ),
                  child: Text(q.enunciado,
                      style: const TextStyle(
                          color: textPrimary, fontSize: 14, height: 1.55)),
                ),
                const SizedBox(height: 12),
                ...q.opcoes.entries.map((e) {
                  final sel = _respostas[_idx] == e.key;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _respostas[_idx] = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sel
                            ? orange.withValues(alpha: 0.1)
                            : navyLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? orange : navyBorder,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel ? orange : navyBorder,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(e.key,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(e.value,
                                style: TextStyle(
                                    color: sel ? textPrimary : textSecondary,
                                    fontSize: 13,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_idx > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _idx--),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: navyBorder)),
                          child: const Text('Anterior',
                              style: TextStyle(color: textSecondary)),
                        ),
                      ),
                    if (_idx > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _idx < _questoes.length - 1
                          ? ElevatedButton(
                              onPressed: () =>
                                  setState(() => _idx++),
                              child: const Text('Próxima'))
                          : ElevatedButton(
                              onPressed: () => _confirmarEncerrar(
                                  respondidas: respondidas),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: green),
                              child: Text(
                                  'Entregar ($respondidas/${_questoes.length})')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarEncerrar({int? respondidas}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: navyLight,
        title: const Text('Encerrar simulado?',
            style: TextStyle(color: textPrimary)),
        content: Text(
          respondidas != null
              ? 'Você respondeu $respondidas/${_questoes.length} questões.'
              : 'O simulado será encerrado.',
          style: const TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar',
                style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _encerrar();
            },
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultado() {
    final r = _resultado!;
    final pct = r.percentual;
    final aprovado = pct >= 0.5;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (aprovado ? green : red).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: (aprovado ? green : red).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(
                  aprovado
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: aprovado ? green : red,
                  size: 48),
              const SizedBox(height: 12),
              Text(aprovado ? 'Aprovado!' : 'Não aprovado',
                  style: TextStyle(
                      color: aprovado ? green : red,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${r.nota} de ${r.total} acertos · ${(pct * 100).round()}%',
                  style: const TextStyle(color: textSecondary, fontSize: 14)),
              Text('Tempo: ${_formatDuracao(r.duracao)}',
                  style: const TextStyle(color: textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Por disciplina
        const Text('Por Disciplina',
            style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...(r.porDisc.entries.toList()
              ..sort((a, b) {
                final pa = (a.value['ok'] ?? 0) / (a.value['total'] ?? 1);
                final pb = (b.value['ok'] ?? 0) / (b.value['total'] ?? 1);
                return pa.compareTo(pb);
              }))
            .map((e) {
          final ok = (e.value['ok'] as int?) ?? 0;
          final total = (e.value['total'] as int?) ?? 1;
          final t = ok / total;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: navyLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: navyBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          context
                                  .read<AppProvider>()
                                  .disciplinas[e.key] ??
                              e.key,
                          style: const TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      Text('$ok/$total',
                          style: const TextStyle(
                              color: textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Text('${(t * 100).round()}%',
                    style: TextStyle(
                        color: t >= 0.7
                            ? green
                            : (t >= 0.5 ? orange : red),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => setState(() {
            _fase = SimuladoFase.inicio;
            _resultado = null;
          }),
          child: const Text('Novo Simulado'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatDuracao(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }
}
