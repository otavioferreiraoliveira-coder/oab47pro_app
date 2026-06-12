import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/kpi_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.carregado) {
      return const Center(
          child: CircularProgressIndicator(color: orange));
    }
    final kpis = app.kpis();
    final priors = app.statsDisciplina().values.toList()
      ..sort((a, b) => b.prioridade.compareTo(a.prioridade));
    final top5 = priors.take(5).toList();

    // Contagem regressiva
    final prova1 = DateTime(2026, 8, 30);
    final hoje = DateTime.now();
    final diasRestantes = prova1.difference(hoje).inDays;

    return Scaffold(
      body: RefreshIndicator(
        color: orange,
        onRefresh: app.sincronizar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Painel',
                          style: TextStyle(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      Text(
                        diasRestantes > 0
                            ? '$diasRestantes dias para a 1ª Fase'
                            : 'Boa sorte na prova!',
                        style: const TextStyle(
                            color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: orange, size: 16),
                      const SizedBox(width: 4),
                      Text('${kpis.streak}d',
                          style: const TextStyle(
                              color: orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // KPIs Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                KpiCard(
                  label: 'QUESTÕES RESPONDIDAS',
                  value: kpis.total.toString(),
                  icon: Icons.quiz_outlined,
                ),
                KpiCard(
                  label: 'TAXA DE ACERTO',
                  value: kpis.taxa != null
                      ? '${(kpis.taxa! * 100).round()}%'
                      : '—',
                  valueColor: _corTaxa(kpis.taxa),
                  icon: Icons.trending_up_outlined,
                ),
                KpiCard(
                  label: 'SIMULADOS',
                  value: kpis.sims.toString(),
                  icon: Icons.timer_outlined,
                ),
                KpiCard(
                  label: 'PROJEÇÃO',
                  value: kpis.proj != null ? '${kpis.proj}/80' : '—',
                  sub: kpis.proj != null
                      ? (kpis.proj! >= 40 ? 'Aprovado ✓' : 'Abaixo do mínimo')
                      : 'Responda 20+ questões',
                  valueColor: kpis.proj != null
                      ? (kpis.proj! >= 40 ? green : red)
                      : null,
                  icon: Icons.lightbulb_outline,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top prioridades
            const Text('Prioridades de Estudo',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...top5.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final taxa = s.taxa;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: navyLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: navyBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nome,
                              style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          Text(
                              taxa != null
                                  ? '${(taxa * 100).round()}% acerto · ${s.resp} respondidas'
                                  : 'Não iniciada',
                              style: const TextStyle(
                                  color: textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (taxa != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _corTaxa(taxa).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${(taxa * 100).round()}%',
                            style: TextStyle(
                                color: _corTaxa(taxa),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              );
            }),

            // Último simulado
            if (kpis.ult != null) ...[
              const SizedBox(height: 20),
              const Text('Último Simulado',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: navyLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: navyBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      kpis.ult!.nota >= kpis.ult!.total * 0.5
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: kpis.ult!.nota >= kpis.ult!.total * 0.5
                          ? green
                          : red,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${kpis.ult!.nota}/${kpis.ult!.total} acertos',
                              style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              '${(kpis.ult!.percentual * 100).round()}% · ${_duracao(kpis.ult!.duracao)}',
                              style: const TextStyle(
                                  color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _corTaxa(double? t) {
    if (t == null) return textMuted;
    if (t >= 0.7) return green;
    if (t >= 0.5) return orange;
    return red;
  }

  String _duracao(int segundos) {
    final h = segundos ~/ 3600;
    final m = (segundos % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}
