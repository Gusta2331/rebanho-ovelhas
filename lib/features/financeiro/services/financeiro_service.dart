import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';

class FinanceiroService {
  SupabaseClient get _client => SupabaseService.client;

  Future<String> _fazendaId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final farm = await _client.from('fazendas').select('id')
        .eq('proprietario_id', user.id).eq('ativo', true).maybeSingle();
    final id = farm?['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> listar({required String loteId}) async {
    final fazendaId = await _fazendaId();
    final result = await _client.from('financeiro_lancamentos').select('*')
        .eq('fazenda_id', fazendaId).eq('lote_id', loteId)
        .order('data', ascending: false).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, double>> resumo({required String loteId}) async {
    final registros = await listar(loteId: loteId);
    double receitas = 0;
    double despesas = 0;
    for (final item in registros) {
      final valor = _number(item['valor']);
      if (item['tipo'] == 'receita') {
        receitas += valor;
      } else {
        despesas += valor;
      }
    }
    return {
      'receitas': receitas,
      'despesas': despesas,
      'saldo': receitas - despesas,
    };
  }

  Future<void> criar({
    required String tipo,
    required String categoria,
    required String descricao,
    required double valor,
    required DateTime data,
    required String loteId,
    String? animalId,
    String? observacoes,
    bool origemAutomatica = false,
  }) async {
    final fazendaId = await _fazendaId();
    if (descricao.trim().isEmpty) throw Exception('Informe a descrição.');
    if (categoria.trim().isEmpty) throw Exception('Informe a categoria.');
    if (valor <= 0) throw Exception('Informe um valor maior que zero.');

    await _client.from('financeiro_lancamentos').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'tipo': tipo,
      'categoria': categoria.trim(),
      'descricao': descricao.trim(),
      'valor': valor,
      'data': data.toIso8601String().split('T').first,
      'lote_id': loteId,
      'animal_id': animalId,
      'origem_automatica': origemAutomatica,
      'observacoes': observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
    });
  }

  Future<void> criarCompraAnimal({
    required String animalId,
    required String loteId,
    required double valor,
    required DateTime data,
    required String brinco,
    String? vendedor,
    String? observacoes,
  }) async {
    if (valor <= 0) {
      throw Exception('O valor da compra deve ser maior que zero.');
    }

    final fazendaId = await _fazendaId();

    final existente = await _client
        .from('financeiro_lancamentos')
        .select('id')
        .eq('fazenda_id', fazendaId)
        .eq('animal_id', animalId)
        .eq('tipo', 'despesa')
        .eq('categoria', 'Compra de animal')
        .eq('origem_automatica', true)
        .maybeSingle();

    if (existente != null) {
      return;
    }

    await criar(
      tipo: 'despesa',
      categoria: 'Compra de animal',
      descricao: 'Compra do animal brinco $brinco',
      valor: valor,
      data: data,
      loteId: loteId,
      animalId: animalId,
      observacoes: [
        if (vendedor != null && vendedor.trim().isNotEmpty)
          'Vendedor: ${vendedor.trim()}',
        if (observacoes != null && observacoes.trim().isNotEmpty)
          observacoes.trim(),
      ].join(' • '),
      origemAutomatica: true,
    );
  }

  Future<void> excluir(String id) async {
    final fazendaId = await _fazendaId();
    await _client.from('financeiro_lancamentos').delete()
        .eq('id', id).eq('fazenda_id', fazendaId);
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
