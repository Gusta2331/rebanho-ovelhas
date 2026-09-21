class Rebanho {
  final String id;
  final String fazendaId;
  final String nome;
  final String? descricao;
  final String? finalidade;
  final String? localizacao;
  final bool ativo;
  final int quantidadeAnimais;

  const Rebanho({
    required this.id,
    required this.fazendaId,
    required this.nome,
    this.descricao,
    this.finalidade,
    this.localizacao,
    this.ativo = true,
    this.quantidadeAnimais = 0,
  });

  factory Rebanho.fromMap(Map<String, dynamic> map) {
    return Rebanho(
      id: map['id'].toString(),
      fazendaId: map['fazenda_id'].toString(),
      nome: map['nome']?.toString() ?? '',
      descricao: _stringOrNull(map['descricao']),
      finalidade: _stringOrNull(map['finalidade']),
      localizacao: _stringOrNull(map['localizacao']),
      ativo: map['ativo'] as bool? ?? true,
      quantidadeAnimais: _quantidadeAnimais(map),
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }

    final texto = value.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return texto;
  }

  static int _quantidadeAnimais(Map<String, dynamic> map) {
    final quantidade = map['quantidade_animais'];

    if (quantidade is int) {
      return quantidade;
    }

    if (quantidade is num) {
      return quantidade.toInt();
    }

    return 0;
  }

  Rebanho copyWith({
    String? id,
    String? fazendaId,
    String? nome,
    String? descricao,
    String? finalidade,
    String? localizacao,
    bool? ativo,
    int? quantidadeAnimais,
  }) {
    return Rebanho(
      id: id ?? this.id,
      fazendaId: fazendaId ?? this.fazendaId,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      finalidade: finalidade ?? this.finalidade,
      localizacao: localizacao ?? this.localizacao,
      ativo: ativo ?? this.ativo,
      quantidadeAnimais: quantidadeAnimais ?? this.quantidadeAnimais,
    );
  }
}
