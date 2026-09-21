import 'package:uuid/uuid.dart';

enum SexoAnimal { femea, macho }

enum StatusAnimal { ativo, vendido, morto, descartado }

class Animal {
  final String id;
  final String brinco;
  final String? nome;
  final SexoAnimal sexo;
  final String raca;
  final DateTime? dataNascimento;
  final StatusAnimal status;
  final String? observacoes;
  final String? fotoPath;

  // Identificação dos pais
  final String? idMae;
  final String? idPai;

  Animal({
    String? id,
    required this.brinco,
    this.nome,
    required this.sexo,
    required this.raca,
    this.dataNascimento,
    this.status = StatusAnimal.ativo,
    this.observacoes,
    this.fotoPath,
    this.idMae,
    this.idPai,
  }) : id = id ?? const Uuid().v4();

  /// Converte um registro vindo do Supabase em um Animal.
  ///
  /// O ID vindo do banco é mantido como o ID permanente do animal.
  /// Isso é importante para edição, filiação e histórico.
  factory Animal.fromMap(Map<String, dynamic> map) {
    final racaRelacionada = map['racas'];

    String nomeRaca = '';

    // Fallback caso exista uma coluna "raca" diretamente no mapa.
    if (map['raca'] is String) {
      nomeRaca = (map['raca'] as String).trim();
    }

    // Quando o Supabase fizer o relacionamento:
    // animais.raca_id -> racas.id
    if (racaRelacionada is Map) {
      final nome = racaRelacionada['nome'];

      if (nome != null && nome.toString().trim().isNotEmpty) {
        nomeRaca = nome.toString().trim();
      }
    }

    return Animal(
      id: _stringOrNull(map['id']) ?? const Uuid().v4(),
      brinco: _formatarBrinco(map['brinco']),
      nome: _stringOrNull(map['nome']),
      sexo: _sexoFromMap(map['sexo']),
      raca: nomeRaca,
      dataNascimento: _dateTimeFromMap(map['data_nascimento']),
      status: _statusFromMap(map['status']),
      observacoes: _stringOrNull(map['observacoes']),
      fotoPath: _stringOrNull(map['foto_url']),
      idMae: _stringOrNull(map['mae_id']),
      idPai: _stringOrNull(map['pai_id']),
    );
  }

  /// Mantém a apresentação do brinco com três dígitos.
  ///
  /// Exemplo:
  /// 1   -> 001
  /// 25  -> 025
  /// 125 -> 125
  static String _formatarBrinco(dynamic value) {
    if (value is int) {
      return value.toString().padLeft(3, '0');
    }

    if (value is num) {
      return value.toInt().toString().padLeft(3, '0');
    }

    if (value is String) {
      final texto = value.trim();
      final numero = int.tryParse(texto);

      if (numero != null) {
        return numero.toString().padLeft(3, '0');
      }

      return texto;
    }

    return '';
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

  static DateTime? _dateTimeFromMap(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  static SexoAnimal _sexoFromMap(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'macho':
        return SexoAnimal.macho;

      case 'femea':
      case 'fêmea':
        return SexoAnimal.femea;

      default:
        return SexoAnimal.femea;
    }
  }

  static StatusAnimal _statusFromMap(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'vendido':
        return StatusAnimal.vendido;

      case 'morto':
        return StatusAnimal.morto;

      case 'descartado':
        return StatusAnimal.descartado;

      case 'ativo':
      default:
        return StatusAnimal.ativo;
    }
  }

  Animal copyWith({
    String? brinco,
    String? nome,
    SexoAnimal? sexo,
    String? raca,
    DateTime? dataNascimento,
    StatusAnimal? status,
    String? observacoes,
    String? fotoPath,
    String? idMae,
    String? idPai,
  }) {
    return Animal(
      id: id,
      brinco: brinco ?? this.brinco,
      nome: nome ?? this.nome,
      sexo: sexo ?? this.sexo,
      raca: raca ?? this.raca,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      status: status ?? this.status,
      observacoes: observacoes ?? this.observacoes,
      fotoPath: fotoPath ?? this.fotoPath,
      idMae: idMae ?? this.idMae,
      idPai: idPai ?? this.idPai,
    );
  }
}
