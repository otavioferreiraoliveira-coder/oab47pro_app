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
import 'resumos_screen.dart';
import 'biblioteca_screen.dart';

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
    _MaisScreen(),
  ];

  static const _labels = ['Painel', 'Praticar', 'Simul.', 'Stats', 'Mentor', 'Mais'];
  static const _icons = [
    Icons.dashboard_outlined, Icons.quiz_outlined, Icons.timer_outlined,
    Icons.bar_chart_outlined, Icons.auto_awesome_outlined, Icons.menu_outlined,
  ];
  static const _iconsSelected = [
    Icons.dashboard, Icons.quiz, Icons.timer,
    Icons.bar_chart, Icons.auto_awesome, Icons.menu,
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
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
            child: Center(child: SyncBadge(synced: app.syncOk)),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: _telas),
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
                        Icon(sel ? _iconsSelected[i] : _icons[i],
                            color: sel ? orange : textMuted, size: 22),
                        const SizedBox(height: 2),
                        Text(_labels[i],
                            style: TextStyle(
                                color: sel ? orange : textMuted,
                                fontSize: 10,
                                fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
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

class _MaisScreen extends StatelessWidget {
  const _MaisScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _item(
            context,
            icon: Icons.headphones_outlined,
            label: 'Resumos & Áudio',
            sub: 'Top 5 por disciplina — baixe para ouvir offline',
            color: orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumosScreen())),
          ),
          const SizedBox(height: 10),
          _item(
            context,
            icon: Icons.library_books_outlined,
            label: 'Biblioteca PDFs',
            sub: 'PDFs do Extensivo Ceisc (Blocos 1-3)',
            color: const Color(0xFF3B82F6),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BibliotecaScreen())),
          ),
          const SizedBox(height: 10),
          _item(
            context,
            icon: Icons.settings_outlined,
            label: 'Configurações',
            sub: 'IA, sincronização, conta',
            color: textSecondary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigScreen())),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
              width: 44, height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
