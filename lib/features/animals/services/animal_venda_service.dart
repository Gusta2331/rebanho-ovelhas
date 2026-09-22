import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../models/animal_venda.dart';

class AnimalVendaService {
  SupabaseClient get _client => SupabaseService.client;

  Future<AnimalVenda?> buscarPorAnimal(String animalId) async {
    final resultado = await _client
        .from('vendas_animais')
        .select('*')
        .eq('animal_id', animalId)
        .maybeSingle();

    if (resultado == null) {
      return null;
    }

    return AnimalVenda.fromMap(Map<String, dynamic>.from(resultado));
  }

  Future<AnimalVenda> venderAnimal({
    required String animalId,
    required String loteId,
    required DateTime dataVenda,
    required TipoVendaAnimal tipoVenda,
    double? pesoKg,
    double? precoPorKg,
    required double valorTotal,
    String? comprador,
    String? observacoes,
  }) async {
    final resultado = await _client.rpc(
      'vender_animal',
      params: {
        'p_animal_id': animalId,
        'p_lote_id': loteId,
        'p_data_venda': dataVenda.toIso8601String().split('T').first,
        'p_tipo_venda': tipoVenda == TipoVendaAnimal.porKg
            ? 'por_kg'
            : 'valor_fechado',
        'p_peso_kg': pesoKg,
        'p_preco_por_kg': precoPorKg,
        'p_valor_total': valorTotal,
        'p_comprador': comprador?.trim(),
        'p_observacoes': observacoes?.trim(),
      },
    );

    final vendaId = resultado?.toString();

    if (vendaId == null || vendaId.isEmpty) {
      throw Exception(
        'A venda foi processada, mas o registro não foi retornado.',
      );
    }

    final venda = await _client
        .from('vendas_animais')
        .select('*')
        .eq('id', vendaId)
        .single();

    return AnimalVenda.fromMap(Map<String, dynamic>.from(venda));
  }
}
