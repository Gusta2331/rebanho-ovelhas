import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_sync_service.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/supabase_service.dart';

class RebanhoService {
  SupabaseClient get _client => SupabaseService.client;
  final OfflineStore _offlineStore = OfflineStore();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  Future<String?> _getMinhaFazendaId() async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    if (!_connectivity.isOnline) {
      return await _offlineStore.lerCache('rebanhos_fazenda_id') as String?;
    }

    final fazenda = await _client
        .from('fazendas')
        .select('id')
        .eq('proprietario_id', usuario.id)
        .eq('ativo', true)
        .maybeSingle();

    final id = fazenda?['id'] as String?;
    if (id != null) await _offlineStore.salvarCache('rebanhos_fazenda_id', id);
    return id;
  }

  Future<List<Map<String, dynamic>>> getRebanhos({
    bool somenteAtivos = false,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('rebanhos_' + (somenteAtivos ? 'ativos' : 'todos'));
      if (cache is List) return cache.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return [];
    }

    var consulta = _client
        .from('rebanhos')
        .select('''
          id,
          fazenda_id,
          nome,
          descricao,
          finalidade,
          localizacao,
          ativo
        ''')
        .eq('fazenda_id', fazendaId);

    if (somenteAtivos) {
      consulta = consulta.eq('ativo', true);
    }

    final resultado = await consulta.order('nome');

    final rebanhos = <Map<String, dynamic>>[];

    for (final item in resultado) {
      final mapa = Map<String, dynamic>.from(item);

      final quantidade = await _contarAnimais(
        fazendaId: fazendaId,
        rebanhoId: mapa['id'].toString(),
      );

      mapa['quantidade_animais'] = quantidade;

      rebanhos.add(mapa);
    }

    await _offlineStore.salvarCache('rebanhos_' + (somenteAtivos ? 'ativos' : 'todos'), rebanhos);
    return rebanhos;
  }

  Future<int> _contarAnimais({
    required String fazendaId,
    required String rebanhoId,
  }) async {
    final resultado = await _client
        .from('animais')
        .select('id')
        .eq('fazenda_id', fazendaId)
        .eq('rebanho_id', rebanhoId)
        .eq('status', 'ativo');

    return resultado.length;
  }

  Future<Map<String, dynamic>?> getRebanhoPorId(String id) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return null;
    }

    final resultado = await _client
        .from('rebanhos')
        .select('''
          id,
          fazenda_id,
          nome,
          descricao,
          finalidade,
          localizacao,
          ativo
        ''')
        .eq('id', id)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (resultado == null) {
      return null;
    }

    final mapa = Map<String, dynamic>.from(resultado);

    mapa['quantidade_animais'] = await _contarAnimais(
      fazendaId: fazendaId,
      rebanhoId: id,
    );

    return mapa;
  }

  Future<Map<String, dynamic>> criarRebanho({
    required String nome,
    String? descricao,
    String? finalidade,
    String? localizacao,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final nomeNormalizado = nome.trim();

    if (nomeNormalizado.isEmpty) {
      throw Exception('Informe o nome do rebanho.');
    }

    final dados = <String, dynamic>{
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'nome': nomeNormalizado,
      'descricao': _valorOuNull(descricao),
      'finalidade': _valorOuNull(finalidade),
      'localizacao': _valorOuNull(localizacao),
      'ativo': true,
    };

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'rebanho.criar', dados: dados,
      );
      final local = {
        ...dados,
        'quantidade_animais': 0,
      };
      await _atualizarCacheRebanho(local);
      return local;
    }

    final resultado = await _client.from('rebanhos').insert(dados).select('''
          id,
          fazenda_id,
          nome,
          descricao,
          finalidade,
          localizacao,
          ativo
        ''').single();

    final mapa = Map<String, dynamic>.from(resultado);
    mapa['quantidade_animais'] = 0;

    return mapa;
  }

  Future<Map<String, dynamic>> atualizarRebanho({
    required String id,
    required String nome,
    String? descricao,
    String? finalidade,
    String? localizacao,
    required bool ativo,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final nomeNormalizado = nome.trim();

    if (nomeNormalizado.isEmpty) {
      throw Exception('Informe o nome do rebanho.');
    }

    final dados = <String, dynamic>{
      'nome': nomeNormalizado,
      'descricao': _valorOuNull(descricao),
      'finalidade': _valorOuNull(finalidade),
      'localizacao': _valorOuNull(localizacao),
      'ativo': ativo,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'rebanho.atualizar',
        dados: {'id': id, 'fazenda_id': fazendaId, ...dados},
      );
      final local = {
        'id': id, 'fazenda_id': fazendaId, ...dados,
        'quantidade_animais': 0,
      };
      await _atualizarCacheRebanho(local);
      return local;
    }

    final resultado = await _client
        .from('rebanhos')
        .update(dados)
        .eq('id', id)
        .eq('fazenda_id', fazendaId)
        .select('''
          id,
          fazenda_id,
          nome,
          descricao,
          finalidade,
          localizacao,
          ativo
        ''')
        .single();

    final mapa = Map<String, dynamic>.from(resultado);

    mapa['quantidade_animais'] = await _contarAnimais(
      fazendaId: fazendaId,
      rebanhoId: id,
    );

    return mapa;
  }

  Future<void> alterarStatus({required String id, required bool ativo}) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final atualizadoEm = DateTime.now().toUtc().toIso8601String();
    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'rebanho.status',
        dados: {
          'id': id, 'fazenda_id': fazendaId,
          'ativo': ativo, 'atualizado_em': atualizadoEm,
        },
      );
      final rebanhos = await getRebanhos();
      Map<String, dynamic>? atual;
      for (final item in rebanhos) {
        if (item['id']?.toString() == id) {
          atual = item;
          break;
        }
      }
      if (atual != null) {
        await _atualizarCacheRebanho({...atual, 'ativo': ativo, 'atualizado_em': atualizadoEm});
      }
      return;
    }

    await _client
        .from('rebanhos')
        .update({
          'ativo': ativo,
          'atualizado_em': atualizadoEm,
        })
        .eq('id', id)
        .eq('fazenda_id', fazendaId);
  }

  String? _valorOuNull(String? valor) {
    if (valor == null) {
      return null;
    }

    final texto = valor.trim();

    if (texto.isEmpty) {
      return null;
    }

    return texto;
  }

  Future<void> _atualizarCacheRebanho(Map<String, dynamic> rebanho) async {
    final id = rebanho['id']?.toString();
    for (final chave in ['rebanhos_todos', 'rebanhos_ativos']) {
      final atual = await _offlineStore.lerCache(chave);
      final lista = atual is List
          ? atual.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      lista.removeWhere((item) => item['id']?.toString() == id);
      if (chave == 'rebanhos_todos' || rebanho['ativo'] == true) {
        lista.add(Map<String, dynamic>.from(rebanho));
      }
      await _offlineStore.salvarCache(chave, lista);
    }
  }
}
