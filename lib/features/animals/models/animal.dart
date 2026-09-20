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
