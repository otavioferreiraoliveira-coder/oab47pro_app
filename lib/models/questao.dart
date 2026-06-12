class Questao {
  final String id;
  final int exame;
  final int bloco;
  final String disciplina;
  final String enunciado;
  final Map<String, String> opcoes;
  final String gabarito;
  final bool anulada;
  final String? lei;

  const Questao({
    required this.id,
    required this.exame,
    required this.bloco,
    required this.disciplina,
    required this.enunciado,
    required this.opcoes,
    required this.gabarito,
    this.anulada = false,
    this.lei,
  });

  factory Questao.fromJson(Map<String, dynamic> j) => Questao(
        id: j['id'] as String,
        exame: (j['exame'] as num).toInt(),
        bloco: (j['bloco'] as num).toInt(),
        disciplina: j['disciplina'] as String,
        enunciado: j['enunciado'] as String,
        opcoes: Map<String, String>.from(j['opcoes'] as Map),
        gabarito: (j['gabarito'] as String?) ?? '',
        anulada: j['anulada'] == true,
        lei: j['lei'] as String?,
      );
}
