import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/estado.dart';
import '../models/questao.dart';
import '../services/sync_service.dart';

class AppProvider extends ChangeNotifier {
  List<Questao> questoes = [];
  Map<String, String> disciplinas = {};
  Map<String, int> blocos = {};
  List<dynamic> planoBase = [];
  EstadoApp estado = EstadoApp();
  bool carregado = false;
  bool syncOk = false;
  Timer? _syncTimer;

  Future<void> carregar() async {
    if (carregado) return;
    final results = await Future.wait([
      rootBundle.loadString('assets/data/questoes.json'),
      rootBundle.loadString('assets/data/meta.json'),
      rootBundle.loadString('assets/data/plano.json'),
    ]);

    final qs = jsonDecode(results[0]) as List;
    questoes = qs.map((j) => Questao.fromJson(j as Map<String, dynamic>)).toList();

    final meta = jsonDecode(results[1]) as Map<String, dynamic>;
    disciplinas = Map<String, String>.from(meta['disciplinas'] as Map);
    blocos = (meta['blocos'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));

    planoBase = jsonDecode(results[2]) as List;

    estado = await SyncService.loadLocal();
    carregado = true;
    notifyListeners();
    _iniciarAutoSync();
  }

  void _iniciarAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => sincronizar());
    sincronizar();
  }

  Future<void> sincronizar() async {
    syncOk = await SyncService.syncToSupabase(estado);
    notifyListeners();
  }

  void responder(String qid, String alt, bool ok, {String modo = 'pratica'}) {
    estado.respostas[qid] = Resposta(alt: alt, ok: ok, ts: DateTime.now().millisecondsSinceEpoch, modo: modo);
    _salvarESinc();
  }

  void salvarSimulado(SimuladoResult sim) {
    final exists = estado.simulados.any((s) => s.id == sim.id);
    if (!exists) estado.simulados.add(sim);
    _salvarESinc();
  }

  void atualizarConfig(ConfigApp cfg) {
    estado.config = cfg;
    estado.configTs = DateTime.now().millisecondsSinceEpoch;
    _salvarESinc();
  }

  void resetarProgresso() {
    estado.respostas.clear();
    estado.simulados.clear();
    estado.plano.clear();
    estado.cacheIA.clear();
    _salvarESinc();
  }

  void atualizarPlano(String key, bool done) {
    estado.plano[key] = {'done': done, 'ts': DateTime.now().millisecondsSinceEpoch};
    _salvarESinc();
  }

  void _salvarESinc() {
    SyncService.saveLocal(estado);
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), sincronizar);
    notifyListeners();
  }

  // ─── Queries ────────────────────────────────────────────────────────────

  List<Questao> filtrar({
    int? bloco,
    String? disciplina,
    int? exame,
    String? status,
    String? busca,
    bool semAnuladas = false,
  }) {
    return questoes.where((q) {
      if (bloco != null && q.bloco != bloco) return false;
      if (disciplina != null && q.disciplina != disciplina) return false;
      if (exame != null && q.exame != exame) return false;
      if (semAnuladas && q.anulada) return false;
      if (status != null) {
        final r = estado.respostas[q.id];
        if (status == 'nao' && r != null) return false;
        if (status == 'erradas' && (r == null || r.ok)) return false;
        if (status == 'acertadas' && (r == null || !r.ok)) return false;
        if (status == 'respondidas' && r == null) return false;
      }
      if (busca != null && busca.isNotEmpty) {
        final t = '${q.enunciado} ${q.opcoes.values.join(' ')}'.toLowerCase();
        if (!t.contains(busca.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  Map<String, StatsDisciplina> statsDisciplina() {
    final peso = <String, double>{};
    final exames = <int>{};
    for (final q in questoes) {
      exames.add(q.exame);
      peso[q.disciplina] = (peso[q.disciplina] ?? 0) + 1;
    }
    final n = exames.isEmpty ? 1.0 : exames.length.toDouble();
    for (final k in peso.keys) { peso[k] = peso[k]! / n; }

    final por = <String, StatsDisciplina>{};
    for (final d in disciplinas.keys) {
      por[d] = StatsDisciplina(
        disc: d,
        nome: disciplinas[d]!,
        bloco: blocos[d] ?? 1,
        peso: peso[d] ?? 0,
      );
    }
    for (final e in estado.respostas.entries) {
      final q = questoes.cast<Questao?>().firstWhere(
          (q) => q?.id == e.key, orElse: () => null);
      if (q == null || por[q.disciplina] == null) continue;
      por[q.disciplina]!.resp++;
      if (e.value.ok) por[q.disciplina]!.ok++;
    }
    for (final s in por.values) {
      s.taxa = s.resp > 0 ? s.ok / s.resp : null;
      final taxaEst = (s.ok + 2.5) / (s.resp + 5);
      s.prioridade = s.peso * (1 - taxaEst);
    }
    return por;
  }

  KPIs kpis() {
    final rs = estado.respostas.values.toList();
    final total = rs.length;
    final ok = rs.where((r) => r.ok).length;
    final sims = estado.simulados;

    final dias = rs.map((r) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.ts);
      return '${d.year}-${d.month}-${d.day}';
    }).toSet();
    int streak = 0;
    for (int i = 0; i <= 400; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';
      if (dias.contains(key)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    int? proj;
    if (sims.isNotEmpty) {
      final ult3 = sims.length > 3 ? sims.sublist(sims.length - 3) : sims;
      proj = (ult3.map((s) => (s.nota / s.total) * 80).reduce((a, b) => a + b) / ult3.length).round();
    } else if (total >= 20) {
      proj = ((ok / total) * 80).round();
    }

    return KPIs(
      total: total,
      ok: ok,
      taxa: total > 0 ? ok / total : null,
      sims: sims.length,
      ult: sims.isNotEmpty ? sims.last : null,
      streak: streak,
      proj: proj,
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

class StatsDisciplina {
  final String disc;
  final String nome;
  final int bloco;
  final double peso;
  int resp = 0;
  int ok = 0;
  double? taxa;
  double prioridade = 0;

  StatsDisciplina({
    required this.disc,
    required this.nome,
    required this.bloco,
    required this.peso,
  });
}

class KPIs {
  final int total;
  final int ok;
  final double? taxa;
  final int sims;
  final SimuladoResult? ult;
  final int streak;
  final int? proj;

  const KPIs({
    required this.total,
    required this.ok,
    this.taxa,
    required this.sims,
    this.ult,
    required this.streak,
    this.proj,
  });
}
