class FarmTransfer {
  final String id;
  final String animalId;
  final String farmOriginId;
  final String farmDestinationId;
  final String farmOriginName;
  final String farmDestinationName;
  final int originTag;
  final int? destinationTag;
  final String status;
  final String operationType;
  final double? saleValue;
  final String? observation;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> animalSnapshot;

  const FarmTransfer({
    required this.id,
    required this.animalId,
    required this.farmOriginId,
    required this.farmDestinationId,
    required this.farmOriginName,
    required this.farmDestinationName,
    required this.originTag,
    required this.status,
    required this.operationType,
    required this.requestedAt,
    required this.animalSnapshot,
    this.destinationTag,
    this.saleValue,
    this.observation,
    this.respondedAt,
    this.completedAt,
  });

  bool get isPending => status == 'pendente';
  bool get isAccepted => status == 'aceita';
  bool get isRejected => status == 'rejeitada';

  String get animalName =>
      animalSnapshot['nome']?.toString().trim().isNotEmpty == true
      ? animalSnapshot['nome'].toString()
      : 'Animal sem nome';

  factory FarmTransfer.fromMap(Map<String, dynamic> map) {
    return FarmTransfer(
      id: map['id'].toString(),
      animalId: map['animal_id'].toString(),
      farmOriginId: map['fazenda_origem_id'].toString(),
      farmDestinationId: map['fazenda_destino_id'].toString(),
      farmOriginName:
          map['nome_fazenda_origem']?.toString() ?? 'Fazenda de origem',
      farmDestinationName:
          map['nome_fazenda_destino']?.toString() ?? 'Fazenda de destino',
      originTag: _toInt(map['brinco_origem']),
      destinationTag: map['brinco_destino'] == null
          ? null
          : _toInt(map['brinco_destino']),
      status: map['status']?.toString() ?? 'pendente',
      operationType: map['tipo_operacao']?.toString() ?? 'transferencia',
      saleValue: _toDouble(map['valor_total']),
      observation: map['observacao']?.toString(),
      requestedAt: DateTime.parse(map['solicitado_em'].toString()).toLocal(),
      respondedAt: _date(map['respondido_em']),
      completedAt: _date(map['concluido_em']),
      animalSnapshot: map['ficha_animal'] is Map
          ? Map<String, dynamic>.from(map['ficha_animal'] as Map)
          : const {},
    );
  }

  static int _toInt(dynamic value) =>
      value is int ? value : int.parse(value.toString());

  static double? _toDouble(dynamic value) => value == null
      ? null
      : value is num
      ? value.toDouble()
      : double.tryParse(value.toString());

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
}

class FarmTransferHistoryEntry {
  final String id;
  final String event;
  final DateTime occurredAt;
  final Map<String, dynamic> details;

  const FarmTransferHistoryEntry({
    required this.id,
    required this.event,
    required this.occurredAt,
    required this.details,
  });

  factory FarmTransferHistoryEntry.fromMap(Map<String, dynamic> map) =>
      FarmTransferHistoryEntry(
        id: map['id'].toString(),
        event: map['evento']?.toString() ?? '',
        occurredAt: DateTime.parse(map['ocorrido_em'].toString()).toLocal(),
        details: map['detalhes'] is Map
            ? Map<String, dynamic>.from(map['detalhes'] as Map)
            : const {},
      );
}
