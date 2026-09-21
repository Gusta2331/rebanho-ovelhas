class Farm {
  final String id;
  final String nome;
  final String proprietarioId;
  final String? nomeProprietario;
  final String? telefone;
  final String? cidade;
  final String? estado;
  final String? endereco;
  final String? observacoes;
  final bool ativo;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  const Farm({
    required this.id,
    required this.nome,
    required this.proprietarioId,
    this.nomeProprietario,
    this.telefone,
    this.cidade,
    this.estado,
    this.endereco,
    this.observacoes,
    required this.ativo,
    this.criadoEm,
    this.atualizadoEm,
  });

  factory Farm.fromMap(Map<String, dynamic> map) {
    return Farm(
      id: map['id'] as String,
      nome: map['nome'] as String,
      proprietarioId: map['proprietario_id'] as String,
      nomeProprietario: map['nome_proprietario'] as String?,
      telefone: map['telefone'] as String?,
      cidade: map['cidade'] as String?,
      estado: map['estado'] as String?,
      endereco: map['endereco'] as String?,
      observacoes: map['observacoes'] as String?,
      ativo: map['ativo'] as bool? ?? true,
      criadoEm: _parseDate(map['criado_em']),
      atualizadoEm: _parseDate(map['atualizado_em']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'proprietario_id': proprietarioId,
      'nome_proprietario': nomeProprietario,
      'telefone': telefone,
      'cidade': cidade,
      'estado': estado,
      'endereco': endereco,
      'observacoes': observacoes,
      'ativo': ativo,
      'criado_em': criadoEm?.toIso8601String(),
      'atualizado_em': atualizadoEm?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
