import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_sync_service.dart';
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
      throw Exception(
        'Sem internet e a fazenda ainda não foi salva neste aparelho.',
      );
    }

    try {
      final farm = await _client
          .from('fazendas')
          .select('id')
          .eq('proprietario_id', user.id)
          .eq('ativo', true)
          .maybeSingle();
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
      return _comOperacoesPendentes(loteId, await _lerCache(loteId));
    }
    try {
      final result = await _client
          .from('financeiro_lancamentos')
          .select('*')
          .eq('fazenda_id', fazendaId)
          .eq('lote_id', loteId)
          .order('data', ascending: false)
          .order('created_at', ascending: false);
      final lista = List<Map<String, dynamic>>.from(result);
      await _offlineStore.salvarCache('financeiro_' + loteId, lista);
      return await _comOperacoesPendentes(loteId, lista);
    } catch (_) {
      return _comOperacoesPendentes(loteId, await _lerCache(loteId));
    }
  }

  Future<List<Map<String, dynamic>>> _lerCache(String loteId) async {
    final cache = await _offlineStore.lerCache('financeiro_' + loteId);
    if (cache is! List) return [];
    return cache
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _comOperacoesPendentes(
    String loteId,
    List<Map<String, dynamic>> registros,
  ) async {
    final resultado = List<Map<String, dynamic>>.from(registros);
    final pendentes = await OfflineSyncService.instance.pendentes();

    for (final operacao in pendentes) {
      final dados = operacao.dados;
      if (operacao.tipo == 'financeiro.criar' &&
          dados['lote_id']?.toString() == loteId) {
        final id = dados['id']?.toString();
        if (id != null &&
            !resultado.any((item) => item['id']?.toString() == id)) {
          resultado.add(Map<String, dynamic>.from(dados));
        }
      } else if (operacao.tipo == 'financeiro.excluir') {
        resultado.removeWhere(
          (item) => item['id']?.toString() == dados['id']?.toString(),
        );
      }
    }

    resultado.sort(
      (a, b) =>
          (b['data']?.toString() ?? '').compareTo(a['data']?.toString() ?? ''),
    );
    return resultado;
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

    final id = const Uuid().v4();
    final dados = <String, dynamic>{
      'id': id,
      'fazenda_id': fazendaId,
      'tipo': tipo,
      'categoria': categoria.trim(),
      'descricao': descricao.trim(),
      'valor': valor,
      'data': data.toIso8601String().split('T').first,
      'lote_id': loteId,
      'animal_id': animalId,
      'observacoes': observacoes?.trim().isEmpty == true
          ? null
          : observacoes?.trim(),
    };

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'financeiro.criar',
        dados: dados,
      );
      final registros = await _lerCache(loteId);
      registros.add(dados);
      await _offlineStore.salvarCache('financeiro_' + loteId, registros);
      return;
    }

    await _client.from('financeiro_lancamentos').insert(dados);
    final registros = await _lerCache(loteId);
    registros.removeWhere((item) => item['id']?.toString() == id);
    registros.add(dados);
    await _offlineStore.salvarCache('financeiro_' + loteId, registros);
  }

  Future<void> excluir(String id, {String? loteId}) async {
    final fazendaId = await _fazendaId();
    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'financeiro.excluir',
        dados: {'id': id, 'fazenda_id': fazendaId, 'lote_id': loteId},
      );
      if (loteId != null) {
        final registros = await _lerCache(loteId);
        registros.removeWhere((item) => item['id']?.toString() == id);
        await _offlineStore.salvarCache('financeiro_' + loteId, registros);
      }
      return;
    }

    await _client
        .from('financeiro_lancamentos')
        .delete()
        .eq('id', id)
        .eq('fazenda_id', fazendaId);
    if (loteId != null) {
      final registros = await _lerCache(loteId);
      registros.removeWhere((item) => item['id']?.toString() == id);
      await _offlineStore.salvarCache('financeiro_' + loteId, registros);
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
