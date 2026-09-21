enum SexoNascimento { femea, macho }

class ReproducaoNascimento {
  final String id;
  final String reproducaoId;
  final String animalId;
  final SexoNascimento sexo;
  final DateTime dataNascimento;
  final String? observacoes;
  final DateTime? criadoEm;

  const ReproducaoNascimento({
    required this.id,
    required this.reproducaoId,
    required this.animalId,
    required this.sexo,
    required this.dataNascimento,
    this.observacoes,
    this.criadoEm,
  });

  factory ReproducaoNascimento.fromMap(Map<String, dynamic> map) {
    return ReproducaoNascimento(
      id: map['id'].toString(),
      reproducaoId: map['reproducao_id'].toString(),
      animalId: map['animal_id'].toString(),
      sexo: _sexoFromString(map['sexo']),
      dataNascimento: DateTime.parse(map['data_nascimento'].toString()),
      observacoes: _stringOrNull(map['observacoes']),
      criadoEm: _parseDateTime(map['criado_em']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reproducao_id': reproducaoId,
      'animal_id': animalId,
      'sexo': _sexoToString(sexo),
      'data_nascimento': dataNascimento.toIso8601String().split('T').first,
      'observacoes': observacoes,
      'criado_em': criadoEm?.toIso8601String(),
    };
  }

  static SexoNascimento _sexoFromString(dynamic value) {
    switch (value?.toString()) {
      case 'macho':
        return SexoNascimento.macho;
      case 'femea':
      default:
        return SexoNascimento.femea;
    }
  }

  static String _sexoToString(SexoNascimento sexo) {
    switch (sexo) {
      case SexoNascimento.femea:
        return 'femea';
      case SexoNascimento.macho:
        return 'macho';
    }
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
