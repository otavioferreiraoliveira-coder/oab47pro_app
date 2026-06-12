class Resposta {
  final String alt;
  final bool ok;
  final int ts;
  final String modo;

  const Resposta(
      {required this.alt,
      required this.ok,
      required this.ts,
      this.modo = 'pratica'});

  factory Resposta.fromJson(Map<String, dynamic> j) => Resposta(
        alt: j['alt'] as String,
        ok: j['ok'] == true,
        ts: (j['ts'] as num?)?.toInt() ?? 0,
        modo: j['modo'] as String? ?? 'pratica',
      );

  Map<String, dynamic> toJson() =>
      {'alt': alt, 'ok': ok, 'ts': ts, 'modo': modo};
}

class SimuladoResult {
  final String id;
  final int ts;
  final String tipo;
  final int nota;
  final int total;
  final int duracao;
  final Map<String, dynamic> porDisc;

  const SimuladoResult({
    required this.id,
    required this.ts,
    required this.tipo,
    required this.nota,
    required this.total,
    required this.duracao,
    required this.porDisc,
  });

  factory SimuladoResult.fromJson(Map<String, dynamic> j) => SimuladoResult(
        id: j['id'] as String,
        ts: (j['ts'] as num?)?.toInt() ?? 0,
        tipo: j['tipo'] as String? ?? 'completo',
        nota: (j['nota'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 80,
        duracao: (j['duracao'] as num?)?.toInt() ?? 0,
        porDisc: Map<String, dynamic>.from(j['porDisc'] as Map? ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts,
        'tipo': tipo,
        'nota': nota,
        'total': total,
        'duracao': duracao,
        'porDisc': porDisc,
      };

  double get percentual => total > 0 ? nota / total : 0;
}

class ConfigApp {
  final String nome;
  final String gemini;
  final String modelo;
  final String ttsVoz;
  final double ttsVel;

  const ConfigApp({
    this.nome = '',
    this.gemini = '',
    this.modelo = 'gemini-2.0-flash',
    this.ttsVoz = '',
    this.ttsVel = 1.0,
  });

  factory ConfigApp.fromJson(Map<String, dynamic> j) => ConfigApp(
        nome: j['nome'] as String? ?? '',
        gemini: j['gemini'] as String? ?? '',
        modelo: j['modelo'] as String? ?? 'gemini-2.0-flash',
        ttsVoz: j['ttsVoz'] as String? ?? '',
        ttsVel: (j['ttsVel'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'gemini': gemini,
        'modelo': modelo,
        'ttsVoz': ttsVoz,
        'ttsVel': ttsVel,
      };

  ConfigApp copyWith({
    String? nome,
    String? gemini,
    String? modelo,
    String? ttsVoz,
    double? ttsVel,
  }) =>
      ConfigApp(
        nome: nome ?? this.nome,
        gemini: gemini ?? this.gemini,
        modelo: modelo ?? this.modelo,
        ttsVoz: ttsVoz ?? this.ttsVoz,
        ttsVel: ttsVel ?? this.ttsVel,
      );
}

class EstadoApp {
  Map<String, Resposta> respostas;
  List<SimuladoResult> simulados;
  Map<String, dynamic> plano;
  ConfigApp config;
  int configTs;
  Map<String, String> cacheIA;

  EstadoApp({
    Map<String, Resposta>? respostas,
    List<SimuladoResult>? simulados,
    Map<String, dynamic>? plano,
    ConfigApp? config,
    this.configTs = 0,
    Map<String, String>? cacheIA,
  })  : respostas = respostas ?? {},
        simulados = simulados ?? [],
        plano = plano ?? {},
        config = config ?? const ConfigApp(),
        cacheIA = cacheIA ?? {};

  factory EstadoApp.fromJson(Map<String, dynamic> j) {
    final resps = <String, Resposta>{};
    final rMap = j['respostas'] as Map? ?? {};
    for (final e in rMap.entries) {
      if (e.value is Map) {
        resps[e.key] = Resposta.fromJson(Map<String, dynamic>.from(e.value));
      }
    }
    final sims = <SimuladoResult>[];
    for (final s in (j['simulados'] as List? ?? [])) {
      if (s is Map) sims.add(SimuladoResult.fromJson(Map<String, dynamic>.from(s)));
    }
    final cache = <String, String>{};
    final cMap = j['cacheIA'] as Map? ?? {};
    for (final e in cMap.entries) {
      if (e.value is String) cache[e.key] = e.value;
    }
    return EstadoApp(
      respostas: resps,
      simulados: sims,
      plano: Map<String, dynamic>.from(j['plano'] as Map? ?? {}),
      config: j['config'] is Map
          ? ConfigApp.fromJson(Map<String, dynamic>.from(j['config'] as Map))
          : const ConfigApp(),
      configTs: (j['configTs'] as num?)?.toInt() ?? 0,
      cacheIA: cache,
    );
  }

  Map<String, dynamic> toJson() => {
        'respostas': respostas.map((k, v) => MapEntry(k, v.toJson())),
        'simulados': simulados.map((s) => s.toJson()).toList(),
        'plano': plano,
        'config': config.toJson(),
        'configTs': configTs,
        'cacheIA': cacheIA,
      };

  void mergeFrom(EstadoApp remote) {
    for (final e in remote.respostas.entries) {
      final cur = respostas[e.key];
      if (cur == null || e.value.ts >= cur.ts) { respostas[e.key] = e.value; }
    }
    final ids = simulados.map((s) => s.id).toSet();
    for (final s in remote.simulados) {
      if (!ids.contains(s.id)) simulados.add(s);
    }
    plano.addAll(remote.plano);
    cacheIA.addAll(remote.cacheIA);
    if (remote.configTs > configTs) {
      config = remote.config;
      configTs = remote.configTs;
    }
  }
}
