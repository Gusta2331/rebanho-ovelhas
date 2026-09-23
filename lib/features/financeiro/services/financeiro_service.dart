import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/services/supabase_service.dart';

class FinanceiroService {
  SupabaseClient get _client => SupabaseService.client;
  final OfflineStore _offlineStore = OfflineStore();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  Future<String> _fazendaId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    const chaveCache = 'financeiro_fazenda_id';

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(chaveCache);
      final id = cache?.toString();
      if (id != null && id.isNotEmpty) return id;
      throw Exception('Sem internet e a fazenda ainda não foi salva neste aparelho.');
    }

    try {
      final farm = await _client.from('fazendas').select('id')
          .eq('proprietario_id', user.id).eq('ativo', true).maybeSingle();
      final id = farm?['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Nenhuma fazenda ativa foi encontrada.');
      }
      await _offlineStore.salvarCache(chaveCache, id);
      return id;
    } catch (_) {
      final cache = await _offlineStore.lerCache(chaveCache);
      final id = cache?.toString();
      if (id != null && id.isNotEmpty) return id;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listar({required String loteId}) async {
    final fazendaId = await _fazendaId();
    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('financeiro_' + loteId);
      if (cache is List) return cache.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return [];
    }
    final result = await _client.from('financeiro_lancamentos').select('*')
        .eq('fazenda_id', fazendaId).eq('lote_id', loteId)
        .order('data', ascending: false).order('created_at', ascending: false);
    final lista = List<Map<String, dynamic>>.from(result);
    await _offlineStore.salvarCache('financeiro_' + loteId, lista);
    return lista;
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
      'observacoes': observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
    });
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
