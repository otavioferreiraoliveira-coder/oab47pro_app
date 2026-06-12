import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/sync_badge.dart';
import 'dashboard_screen.dart';
import 'praticar_screen.dart';
import 'simulado_screen.dart';
import 'estatisticas_screen.dart';
import 'mentor_screen.dart';
import 'config_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _telas = [
    DashboardScreen(),
    PraticarScreen(),
    SimuladoScreen(),
    EstatisticasScreen(),
    MentorScreen(),
    ConfigScreen(),
  ];

  static const _labels = [
    'Painel',
    'Praticar',
    'Simulado',
    'Stats',
    'Mentor',
    'Config',
  ];

  static const _icons = [
    Icons.dashboard_outlined,
    Icons.quiz_outlined,
    Icons.timer_outlined,
    Icons.bar_chart_outlined,
    Icons.auto_awesome_outlined,
    Icons.settings_outlined,
  ];

  static const _iconsSelected = [
    Icons.dashboard,
    Icons.quiz,
    Icons.timer,
    Icons.bar_chart,
    Icons.auto_awesome,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.5),
            children: [
              TextSpan(text: 'OAB'),
              TextSpan(text: '47', style: TextStyle(color: orange)),
              TextSpan(text: 'PRO'),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: SyncBadge(synced: app.syncOk),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: _telas,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: navyLight,
          border: Border(top: BorderSide(color: navyBorder, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_telas.length, (i) {
                final sel = _tab == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          sel ? _iconsSelected[i] : _icons[i],
                          color: sel ? orange : textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _labels[i],
                          style: TextStyle(
                            color: sel ? orange : textMuted,
                            fontSize: 10,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
