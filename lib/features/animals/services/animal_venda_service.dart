import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_sync_service.dart';

import '../../../core/services/supabase_service.dart';
import '../models/animal_venda.dart';

class AnimalVendaService {
  SupabaseClient get _client => SupabaseService.client;
  final ConnectivityService _connectivity = ConnectivityService.instance;

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

  Future<void> venderAnimal({
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
    final tipoTexto = tipoVenda == TipoVendaAnimal.porKg
        ? 'por_kg'
        : 'valor_fechado';
    final dataTexto = dataVenda.toIso8601String().split('T').first;

    if (!_connectivity.isOnline) {
      final pendentes = await OfflineSyncService.instance.pendentes();
      final vendaJaPendente = pendentes.any(
        (operacao) =>
            operacao.tipo == 'animal.venda' &&
            operacao.dados['animal_id']?.toString() == animalId,
      );
      if (vendaJaPendente) {
        throw Exception(
          'Já existe uma venda deste animal aguardando sincronização.',
        );
      }

      await OfflineSyncService.instance.enfileirar(
        tipo: 'animal.venda',
        dados: {
          'animal_id': animalId,
          'lote_id': loteId,
          'data_venda': dataTexto,
          'tipo_venda': tipoTexto,
          'peso_kg': pesoKg,
          'preco_por_kg': precoPorKg,
          'valor_total': valorTotal,
          'comprador': comprador?.trim(),
          'observacoes': observacoes?.trim(),
        },
      );

      return;
    }

    final dynamic resultado = await _client.rpc<dynamic>(
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

    // A função do banco pode retornar booleano (true/false), não o ID da venda.
    // O registro já é gravado no banco; não tente converter o resultado em String.
    if (resultado == false) {
      throw Exception('O banco de dados não confirmou o registro da venda.');
    }
  }
}
