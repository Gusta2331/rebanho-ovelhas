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

  String _chaveCache(String? loteId) => 'financeiro_${loteId ?? 'fazenda'}';

  Future<List<Map<String, dynamic>>> listar({String? loteId}) async {
    final fazendaId = await _fazendaId();
    final chaveCache = _chaveCache(loteId);
    if (!_connectivity.isOnline) {
      return _comOperacoesPendentes(loteId, await _lerCache(chaveCache));
    }
    try {
      var consulta = _client
          .from('financeiro_lancamentos')
          .select('*')
          .eq('fazenda_id', fazendaId);
      if (loteId != null) consulta = consulta.eq('lote_id', loteId);
      final result = await consulta
          .order('data', ascending: false)
          .order('created_at', ascending: false);
      final lista = List<Map<String, dynamic>>.from(result);
      await _offlineStore.salvarCache(chaveCache, lista);
      return await _comOperacoesPendentes(loteId, lista);
    } catch (_) {
      return _comOperacoesPendentes(loteId, await _lerCache(chaveCache));
    }
  }

  Future<List<Map<String, dynamic>>> _lerCache(String chaveCache) async {
    final cache = await _offlineStore.lerCache(chaveCache);
    if (cache is! List) return [];
    return cache
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _comOperacoesPendentes(
    String? loteId,
    List<Map<String, dynamic>> registros,
  ) async {
    final resultado = List<Map<String, dynamic>>.from(registros);
    final pendentes = await OfflineSyncService.instance.pendentes();

    for (final operacao in pendentes) {
      final dados = operacao.dados;
      if (operacao.tipo == 'financeiro.criar' &&
          (loteId == null || dados['lote_id']?.toString() == loteId)) {
        final id = dados['id']?.toString();
        if (id != null &&
            !resultado.any((item) => item['id']?.toString() == id)) {
          resultado.add(Map<String, dynamic>.from(dados));
        }
      } else if (operacao.tipo == 'financeiro.excluir' &&
          (loteId == null || dados['lote_id']?.toString() == loteId)) {
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

  Future<Map<String, double>> resumo({String? loteId}) async {
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
    String? loteId,
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
      await _adicionarAoCache(dados);
      return;
    }

    await _client.from('financeiro_lancamentos').insert(dados);
    await _adicionarAoCache(dados);
  }

  Future<void> _adicionarAoCache(Map<String, dynamic> dados) async {
    final chaves = <String>{_chaveCache(null)};
    final loteId = dados['lote_id']?.toString();
    if (loteId != null) chaves.add(_chaveCache(loteId));
    for (final chave in chaves) {
      final registros = await _lerCache(chave);
      final id = dados['id']?.toString();
      registros.removeWhere((item) => item['id']?.toString() == id);
      registros.add(Map<String, dynamic>.from(dados));
      await _offlineStore.salvarCache(chave, registros);
    }
  }

  Future<void> excluir(String id, {String? loteId}) async {
    final fazendaId = await _fazendaId();
    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'financeiro.excluir',
        dados: {'id': id, 'fazenda_id': fazendaId, 'lote_id': loteId},
      );
      await _removerDosCaches(id, loteId);
      return;
    }

    await _client
        .from('financeiro_lancamentos')
        .delete()
        .eq('id', id)
        .eq('fazenda_id', fazendaId);
    await _removerDosCaches(id, loteId);
  }

  Future<void> _removerDosCaches(String id, String? loteId) async {
    final chaves = <String>{_chaveCache(null)};
    if (loteId != null) chaves.add(_chaveCache(loteId));
    for (final chave in chaves) {
      final registros = await _lerCache(chave);
      registros.removeWhere((item) => item['id']?.toString() == id);
      await _offlineStore.salvarCache(chave, registros);
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
