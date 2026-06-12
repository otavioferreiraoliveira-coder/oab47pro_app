import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../widgets/sync_badge.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _nomeCtrl = TextEditingController();
  final _geminiCtrl = TextEditingController();
  String _modelo = 'gemini-2.0-flash';
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<AppProvider>().estado.config;
    _nomeCtrl.text = cfg.nome;
    _geminiCtrl.text = cfg.gemini;
    _modelo = cfg.modelo.isNotEmpty ? cfg.modelo : 'gemini-2.0-flash';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _geminiCtrl.dispose();
    super.dispose();
  }

  void _salvar() {
    final app = context.read<AppProvider>();
    setState(() => _salvando = true);
    app.atualizarConfig(app.estado.config.copyWith(
      nome: _nomeCtrl.text.trim(),
      gemini: _geminiCtrl.text.trim(),
      modelo: _modelo,
    ));
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _salvando = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = AuthService.currentUser;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Conta
          _secao('Conta'),
          _tile(
            leading: const Icon(Icons.person_outline, color: textSecondary),
            title: user?.email ?? 'Não autenticado',
            sub: 'Conta Supabase',
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SyncBadge(synced: app.syncOk),
                  const SizedBox(width: 4),
                  Text(app.syncOk ? 'Sincronizado' : 'Offline',
                      style: TextStyle(
                          color: app.syncOk ? green : textMuted,
                          fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _confirmarLogout(context),
            icon: const Icon(Icons.logout, size: 16, color: red),
            label: const Text('Sair', style: TextStyle(color: red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: red, width: 0.8),
            ),
          ),

          const SizedBox(height: 20),
          _secao('Perfil'),
          TextField(
            controller: _nomeCtrl,
            style: const TextStyle(color: textPrimary),
            decoration: const InputDecoration(labelText: 'Seu nome'),
          ),

          const SizedBox(height: 20),
          _secao('Inteligência Artificial'),
          const Text(
            'Chave da API Google Gemini (gratuita em aistudio.google.com)',
            style: TextStyle(color: textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _geminiCtrl,
            style: const TextStyle(color: textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Chave Gemini',
              prefixIcon:
                  Icon(Icons.key_outlined, size: 18, color: textMuted),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Modelo',
              style: TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          _dropModelo(),

          const SizedBox(height: 20),
          _secao('Sincronização'),
          _tile(
            leading:
                const Icon(Icons.sync, color: textSecondary),
            title: 'Sincronizar agora',
            sub: 'Envia dados ao Supabase',
            onTap: () => app.sincronizar(),
          ),
          _tile(
            leading:
                const Icon(Icons.storage_outlined, color: textSecondary),
            title: 'Status',
            sub: app.syncOk
                ? 'Último sync: OK'
                : 'Offline — dados salvos localmente',
          ),

          const SizedBox(height: 20),
          _secao('Dados'),
          _tile(
            leading: const Icon(Icons.warning_amber_outlined,
                color: red),
            title: 'Resetar progresso',
            sub: 'Remove todo o histórico local',
            titleColor: red,
            onTap: () => _confirmarReset(context),
          ),

          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Salvar Configurações'),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text('OAB47PRO · v1.0',
                style: TextStyle(color: textMuted, fontSize: 11)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _secao(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              color: orange, fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
    );
  }

  Widget _tile({
    required Widget leading,
    required String title,
    String? sub,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: navyLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: navyBorder),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor ?? textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (sub != null)
                    Text(sub,
                        style: const TextStyle(
                            color: textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (trailing case final t?) t,
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right,
                  color: textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _dropModelo() {
    const modelos = [
      'gemini-2.0-flash',
      'gemini-2.5-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: navyLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: navyBorder),
      ),
      child: DropdownButton<String>(
        value: modelos.contains(_modelo) ? _modelo : modelos.first,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: navyLight,
        style: const TextStyle(color: textPrimary, fontSize: 13),
        onChanged: (v) => setState(() => _modelo = v ?? _modelo),
        items: modelos
            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
            .toList(),
      ),
    );
  }

  void _confirmarLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: navyLight,
        title: const Text('Sair?',
            style: TextStyle(color: textPrimary)),
        content: const Text(
            'Seu progresso está salvo na nuvem.',
            style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AuthService.signOut();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _confirmarReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: navyLight,
        title: const Text('Resetar progresso?',
            style: TextStyle(color: red)),
        content: const Text(
            'Esta ação remove todo seu histórico local. Não pode ser desfeita.',
            style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AppProvider>().resetarProgresso();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
  }
}
