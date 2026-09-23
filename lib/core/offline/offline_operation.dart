class OfflineOperation {
  final String id;
  final String tipo;
  final Map<String, dynamic> dados;
  final DateTime criadoEm;
  final int tentativas;
  final String? ultimoErro;

  const OfflineOperation({
    required this.id,
    required this.tipo,
    required this.dados,
    required this.criadoEm,
    this.tentativas = 0,
    this.ultimoErro,
  });

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'].toString(),
      tipo: json['tipo'].toString(),
      dados: Map<String, dynamic>.from(json['dados'] as Map),
      criadoEm: DateTime.parse(json['criado_em'].toString()),
      tentativas: (json['tentativas'] as num?)?.toInt() ?? 0,
      ultimoErro: json['ultimo_erro']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'dados': dados,
      'criado_em': criadoEm.toIso8601String(),
      'tentativas': tentativas,
      'ultimo_erro': ultimoErro,
    };
  }

  OfflineOperation comErro(Object erro) {
    return OfflineOperation(
      id: id,
      tipo: tipo,
      dados: dados,
      criadoEm: criadoEm,
      tentativas: tentativas + 1,
      ultimoErro: erro.toString(),
    );
  }
}
