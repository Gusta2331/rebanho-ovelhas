import 'package:uuid/uuid.dart';

enum TipoManejo { vacinacao, vermifugacao, tratamento, tosquia, pesagem, famacha, outro }

class Manejo {
  final String id;
  final String animalId;
  final TipoManejo tipo;
  final DateTime data;
  final int? famachaEscore;
  final String? observacoes;
  final String? vacinaId;
  final String? vacinaNome;
  final String? vacinaFabricante;
  final String? vacinaLote;
  final String? outroNome;
  final double? pesoKg;
  final double? dose;
  final String? doseUnidade;
  final double? pesoReferenciaKg;
  final String? viaAplicacao;
  final DateTime? validade;
  final int? carenciaDias;
  final String? vermifugoId;
  final String? vermifugoNome;
  final String? vermifugoPrincipioAtivo;
  final String? medicamentoId;
  final String? medicamentoNome;
  final String? medicamentoPrincipioAtivo;
  final String? enfermidade;

  Manejo({
    String? id,
    required this.animalId,
    required this.tipo,
    required this.data,
    this.famachaEscore,
    this.observacoes,
    this.vacinaId,
    this.vacinaNome,
    this.vacinaFabricante,
    this.vacinaLote,
    this.outroNome,
    this.pesoKg,
    this.dose,
    this.doseUnidade,
    this.pesoReferenciaKg,
    this.viaAplicacao,
    this.validade,
    this.carenciaDias,
    this.vermifugoId,
    this.vermifugoNome,
    this.vermifugoPrincipioAtivo,
    this.medicamentoId,
    this.medicamentoNome,
    this.medicamentoPrincipioAtivo,
    this.enfermidade,
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
      vacinaId: _stringOrNull(map['vacina_id']),
      vacinaNome: _stringOrNull(map['vacina_nome']),
      vacinaFabricante: _stringOrNull(map['vacina_fabricante']),
      vacinaLote: _stringOrNull(map['vacina_lote']),
      outroNome: _stringOrNull(map['outro_nome']),
      pesoKg: _doubleOrNull(map['peso_kg']),
      dose: _doubleOrNull(map['dose']),
      doseUnidade: _stringOrNull(map['dose_unidade']),
      pesoReferenciaKg: _doubleOrNull(map['peso_referencia_kg']),
      viaAplicacao: _stringOrNull(map['via_aplicacao']),
      validade: _dateOrNull(map['validade']),
      carenciaDias: _intOrNull(map['carencia_dias']),
      vermifugoId: _stringOrNull(map['vermifugo_id']),
      vermifugoNome: _stringOrNull(map['vermifugo_nome']),
      vermifugoPrincipioAtivo: _stringOrNull(map['vermifugo_principio_ativo']),
      medicamentoId: _stringOrNull(map['medicamento_id']),
      medicamentoNome: _stringOrNull(map['medicamento_nome']),
      medicamentoPrincipioAtivo: _stringOrNull(map['medicamento_principio_ativo']),
      enfermidade: _stringOrNull(map['enfermidade']),
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

  static double? _doubleOrNull(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString().replaceAll(',', '.'));
  }

  static int? _intOrNull(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString());
  }

  static DateTime? _dateOrNull(dynamic valor) {
    if (valor == null) return null;
    return DateTime.tryParse(valor.toString());
  }

  static String? _stringOrNull(dynamic valor) {
    if (valor == null) return null;
    final texto = valor.toString().trim();
    return texto.isEmpty ? null : texto;
  }
}
