enum TipoVendaAnimal {
  valorFechado,
  porKg,
}

class AnimalVenda {
  final String id;
  final String animalId;
  final String loteId;
  final DateTime dataVenda;
  final TipoVendaAnimal tipoVenda;
  final double? pesoKg;
  final double? precoPorKg;
  final double valorTotal;
  final String? comprador;
  final String? observacoes;

  const AnimalVenda({
    required this.id,
    required this.animalId,
    required this.loteId,
    required this.dataVenda,
    required this.tipoVenda,
    this.pesoKg,
    this.precoPorKg,
    required this.valorTotal,
    this.comprador,
    this.observacoes,
  });

  factory AnimalVenda.fromMap(Map<String, dynamic> map) {
    return AnimalVenda(
      id: map['id'].toString(),
      animalId: map['animal_id'].toString(),
      loteId: map['lote_id'].toString(),
      dataVenda: DateTime.parse(map['data_venda'].toString()),
      tipoVenda: map['tipo_venda'] == 'por_kg'
          ? TipoVendaAnimal.porKg
          : TipoVendaAnimal.valorFechado,
      pesoKg: _doubleOrNull(map['peso_kg']),
      precoPorKg: _doubleOrNull(map['preco_por_kg']),
      valorTotal: _doubleOrNull(map['valor_total']) ?? 0,
      comprador: _stringOrNull(map['comprador']),
      observacoes: _stringOrNull(map['observacoes']),
    );
  }

  static double? _doubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
