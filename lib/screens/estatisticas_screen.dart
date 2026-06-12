import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';

class EstatisticasScreen extends StatelessWidget {
  const EstatisticasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.carregado) {
      return const Center(child: CircularProgressIndicator(color: orange));
    }
    final stats = app.statsDisciplina();
    final lista = stats.values.toList()
      ..sort((a, b) => (a.taxa ?? -1).compareTo(b.taxa ?? -1));

    final respondidas = lista.where((s) => s.resp > 0).toList();

    if (respondidas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Responda questões para ver suas estatísticas.',
            style: TextStyle(color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Estatísticas',
            style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),

        // Gráfico de barras — taxa por disciplina
        const Text('Taxa de Acerto por Disciplina',
            style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style:
                            const TextStyle(color: textMuted, fontSize: 9)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx >= respondidas.length) return const SizedBox();
                      final nome = respondidas[idx].nome;
                      final abbr = nome.length > 5
                          ? nome.substring(0, 5)
                          : nome;
                      return Text(abbr,
                          style: const TextStyle(
                              color: textMuted, fontSize: 9));
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: navyBorder, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              barGroups: respondidas.asMap().entries.map((e) {
                final t = (e.value.taxa ?? 0) * 100;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: t,
                      color: t >= 70
                          ? green
                          : (t >= 50 ? orange : red),
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Lista detalhada
        const Text('Detalhamento',
            style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...lista.map((s) {
          if (s.resp == 0) return const SizedBox.shrink();
          final t = s.taxa ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(s.nome,
                          style: const TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                    Text('${s.ok}/${s.resp}',
                        style: const TextStyle(
                            color: textMuted, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${(t * 100).round()}%',
                        style: TextStyle(
                            color:
                                t >= 0.7 ? green : (t >= 0.5 ? orange : red),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: t,
                    backgroundColor: navyBorder,
                    color:
                        t >= 0.7 ? green : (t >= 0.5 ? orange : red),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),

        // Histórico de simulados (linha do tempo)
        if (app.estado.simulados.isNotEmpty) ...[
          const Text('Evolução nos Simulados',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                          style: const TextStyle(
                              color: textMuted, fontSize: 9)),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: navyBorder, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: app.estado.simulados.asMap().entries.map((e) {
                      final pct = e.value.percentual * 100;
                      return FlSpot(e.key.toDouble(), pct);
                    }).toList(),
                    isCurved: true,
                    color: orange,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: orange.withValues(alpha: 0.1),
                    ),
                  ),
                  // Linha de aprovação (50%)
                  LineChartBarData(
                    spots: [
                      FlSpot(0, 50),
                      FlSpot(
                          (app.estado.simulados.length - 1).toDouble(), 50),
                    ],
                    isCurved: false,
                    color: red.withValues(alpha: 0.4),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    dashArray: [4, 4],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
