class Monta {
  final String id;
  final String reproducaoId;
  final String carneiroId;
  final DateTime dataMonta;
  final String? observacoes;
  final DateTime? criadoEm;

  const Monta({
    required this.id,
    required this.reproducaoId,
    required this.carneiroId,
    required this.dataMonta,
    this.observacoes,
    this.criadoEm,
  });

  factory Monta.fromMap(Map<String, dynamic> map) {
    return Monta(
      id: map['id'].toString(),
      reproducaoId: map['reproducao_id'].toString(),
      carneiroId: map['carneiro_id'].toString(),
      dataMonta: DateTime.parse(map['data_cobertura'].toString()),
      observacoes: _stringOrNull(map['observacoes']),
      criadoEm: _parseDateTime(map['criado_em']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reproducao_id': reproducaoId,
      'carneiro_id': carneiroId,
      'data_cobertura': dataMonta.toIso8601String().split('T').first,
      'observacoes': observacoes,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  Monta copyWith({
    String? id,
    String? reproducaoId,
    String? carneiroId,
    DateTime? dataMonta,
    String? observacoes,
    DateTime? criadoEm,
  }) {
    return Monta(
      id: id ?? this.id,
      reproducaoId: reproducaoId ?? this.reproducaoId,
      carneiroId: carneiroId ?? this.carneiroId,
      dataMonta: dataMonta ?? this.dataMonta,
      observacoes: observacoes ?? this.observacoes,
      criadoEm: criadoEm ?? this.criadoEm,
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }
}
