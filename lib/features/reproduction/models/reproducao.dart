enum StatusReproducao {
  planejada,
  coberta,
  prenhe,
  naoPrenhe,
  abortou,
  partoRealizado,
  encerrada,
}

class Reproducao {
  final String id;
  final String fazendaId;
  final String maeId;
  final String? paiId;
  final DateTime? dataCobertura;
  final DateTime? dataPrevisaoParto;
  final DateTime? dataConfirmacaoPrenhez;
  final DateTime? dataParto;
  final StatusReproducao status;
  final String? observacoes;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  const Reproducao({
    required this.id,
    required this.fazendaId,
    required this.maeId,
    this.paiId,
    this.dataCobertura,
    this.dataPrevisaoParto,
    this.dataConfirmacaoPrenhez,
    this.dataParto,
    this.status = StatusReproducao.planejada,
    this.observacoes,
    this.criadoEm,
    this.atualizadoEm,
  });

  factory Reproducao.fromMap(Map<String, dynamic> map) {
    return Reproducao(
      id: map['id'].toString(),
      fazendaId: map['fazenda_id'].toString(),
      maeId: map['mae_id'].toString(),
      paiId: _stringOrNull(map['pai_id']),
      dataCobertura: _parseDate(map['data_cobertura']),
      dataPrevisaoParto: _parseDate(map['data_previsao_parto']),
      dataConfirmacaoPrenhez: _parseDate(map['data_confirmacao_prenhez']),
      dataParto: _parseDate(map['data_parto']),
      status: _statusFromString(map['status']),
      observacoes: _stringOrNull(map['observacoes']),
      criadoEm: _parseDateTime(map['criado_em']),
      atualizadoEm: _parseDateTime(map['atualizado_em']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fazenda_id': fazendaId,
      'mae_id': maeId,
      'pai_id': paiId,
      'data_cobertura': dataCobertura?.toIso8601String().split('T').first,
      'data_previsao_parto': dataPrevisaoParto
          ?.toIso8601String()
          .split('T')
          .first,
      'data_confirmacao_prenhez': dataConfirmacaoPrenhez?.toIso8601String().split('T').first,
      'data_parto': dataParto?.toIso8601String().split('T').first,
      'status': _statusToString(status),
      'observacoes': observacoes,
      'criado_em': criadoEm?.toIso8601String(),
      'atualizado_em': atualizadoEm?.toIso8601String(),
    };
  }

  Reproducao copyWith({
    String? id,
    String? fazendaId,
    String? maeId,
    String? paiId,
    DateTime? dataCobertura,
    DateTime? dataPrevisaoParto,
    DateTime? dataConfirmacaoPrenhez,
    DateTime? dataParto,
    StatusReproducao? status,
    String? observacoes,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
  }) {
    return Reproducao(
      id: id ?? this.id,
      fazendaId: fazendaId ?? this.fazendaId,
      maeId: maeId ?? this.maeId,
      paiId: paiId ?? this.paiId,
      dataCobertura: dataCobertura ?? this.dataCobertura,
      dataPrevisaoParto: dataPrevisaoParto ?? this.dataPrevisaoParto,
      dataConfirmacaoPrenhez: dataConfirmacaoPrenhez ?? this.dataConfirmacaoPrenhez,
      dataParto: dataParto ?? this.dataParto,
      status: status ?? this.status,
      observacoes: observacoes ?? this.observacoes,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }

  static StatusReproducao _statusFromString(dynamic value) {
    switch (value?.toString()) {
      case 'coberta':
        return StatusReproducao.coberta;

      case 'prenhe':
        return StatusReproducao.prenhe;

      case 'nao_prenhe':
        return StatusReproducao.naoPrenhe;

      case 'abortou':
        return StatusReproducao.abortou;

      case 'parto_realizado':
        return StatusReproducao.partoRealizado;

      case 'encerrada':
        return StatusReproducao.encerrada;

      case 'planejada':
      default:
        return StatusReproducao.planejada;
    }
  }

  static String _statusToString(StatusReproducao status) {
    switch (status) {
      case StatusReproducao.planejada:
        return 'planejada';

      case StatusReproducao.coberta:
        return 'coberta';

      case StatusReproducao.prenhe:
        return 'prenhe';

      case StatusReproducao.naoPrenhe:
        return 'nao_prenhe';

      case StatusReproducao.abortou:
        return 'abortou';

      case StatusReproducao.partoRealizado:
        return 'parto_realizado';

      case StatusReproducao.encerrada:
        return 'encerrada';
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }

    return DateTime.tryParse(value.toString());
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
}
