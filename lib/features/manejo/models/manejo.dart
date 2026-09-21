import 'package:uuid/uuid.dart';

enum TipoManejo { vacinacao, vermifugacao, tratamento, tosquia, pesagem, famacha, outro }

class Manejo {
  final String id;
  final String animalId;
  final TipoManejo tipo;
  final DateTime data;
  final int? famachaEscore;
  final String? observacoes;

  Manejo({
    String? id,
    required this.animalId,
    required this.tipo,
    required this.data,
    this.famachaEscore,
    this.observacoes,
  }) : id = id ?? const Uuid().v4();

  factory Manejo.fromMap(Map<String, dynamic> map) {
    return Manejo(
      id: map['id']?.toString(),
      animalId: map['animal_id'].toString(),
      tipo: tipoFromString(map['tipo']?.toString()),
      data: DateTime.tryParse(map['data']?.toString() ?? '') ?? DateTime.now(),
      famachaEscore: map['famacha_escore'] is num
          ? (map['famacha_escore'] as num).toInt()
          : int.tryParse(map['famacha_escore']?.toString() ?? ''),
      observacoes: _stringOrNull(map['observacoes']),
    );
  }

  static TipoManejo tipoFromString(String? valor) {
    switch (valor) {
      case 'vacinacao': return TipoManejo.vacinacao;
      case 'vermifugacao': return TipoManejo.vermifugacao;
      case 'tratamento': return TipoManejo.tratamento;
      case 'tosquia': return TipoManejo.tosquia;
      case 'pesagem': return TipoManejo.pesagem;
      case 'famacha': return TipoManejo.famacha;
      default: return TipoManejo.outro;
    }
  }

  static String tipoToString(TipoManejo tipo) {
    switch (tipo) {
      case TipoManejo.vacinacao: return 'vacinacao';
      case TipoManejo.vermifugacao: return 'vermifugacao';
      case TipoManejo.tratamento: return 'tratamento';
      case TipoManejo.tosquia: return 'tosquia';
      case TipoManejo.pesagem: return 'pesagem';
      case TipoManejo.famacha: return 'famacha';
      case TipoManejo.outro: return 'outro';
    }
  }

  static String? _stringOrNull(dynamic valor) {
    if (valor == null) return null;
    final texto = valor.toString().trim();
    return texto.isEmpty ? null : texto;
  }
}
