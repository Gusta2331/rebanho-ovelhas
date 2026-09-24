import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/services/supabase_service.dart';
import 'rebanho_service.dart';

class AnimalTransferService {
  SupabaseClient get _client => SupabaseService.client;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final OfflineStore _offlineStore = OfflineStore();

  Future<String?> _getMinhaFazendaId() async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('fazenda_id_${usuario.id}') as String?;
      return cache ?? await _offlineStore.lerCache('rebanhos_fazenda_id') as String?;
    }

    final fazenda = await _client
        .from('fazendas')
        .select('id')
        .eq('proprietario_id', usuario.id)
        .eq('ativo', true)
        .maybeSingle();

    final id = fazenda?['id'] as String?;
    if (id != null) {
      await _offlineStore.salvarCache('fazenda_id_${usuario.id}', id);
      await _offlineStore.salvarCache('rebanhos_fazenda_id', id);
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> getRebanhosDisponiveis({
    required String rebanhoAtualId,
  }) async {
    if (!_connectivity.isOnline) {
      final cache = await RebanhoService().getRebanhos(somenteAtivos: true);
      return cache
          .where((item) => item['id']?.toString() != rebanhoAtualId)
          .toList();
    }

    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
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
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .neq('id', rebanhoAtualId)
        .order('nome');

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getHistoricoTransferencias({
    required String animalId,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(_historicoCacheKey(fazendaId, animalId));
      final rebanhos = await _offlineStore.lerCache('rebanhos_todos');
      final nomes = <String, String>{};
      if (rebanhos is List) {
        for (final item in rebanhos.whereType<Map>()) {
          nomes[item['id']?.toString() ?? ''] = item['nome']?.toString() ?? '';
        }
      }
      if (cache is! List) return [];
      return cache.whereType<Map>().map((item) {
        final linha = Map<String, dynamic>.from(item);
        linha['rebanho_origem'] = {'nome': nomes[linha['rebanho_origem_id']?.toString()]};
        linha['rebanho_destino'] = {'nome': nomes[linha['rebanho_destino_id']?.toString()]};
        return linha;
      }).toList();
    }

    final resultado = await _client
        .from('animal_transferencias')
        .select('''
          id,
          animal_id,
          fazenda_id,
          rebanho_origem_id,
          rebanho_destino_id,
          data_transferencia,
          observacao,
          criado_em,
          rebanho_origem:rebanhos!animal_transferencias_rebanho_origem_id_fkey(
            id,
            nome
          ),
          rebanho_destino:rebanhos!animal_transferencias_rebanho_destino_id_fkey(
            id,
            nome
          )
        ''')
        .eq('animal_id', animalId)
        .eq('fazenda_id', fazendaId)
        .order('data_transferencia', ascending: false);

    final lista = List<Map<String, dynamic>>.from(resultado);
    await _offlineStore.salvarCache(_historicoCacheKey(fazendaId, animalId), lista);
    return lista;
  }

  Future<bool> transferirAnimal({
    required String animalId,
    required String rebanhoOrigemId,
    required String rebanhoDestinoId,
    String? observacao,
    DateTime? dataTransferencia,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    if (rebanhoOrigemId == rebanhoDestinoId) {
      throw Exception('O animal já está neste rebanho.');
    }

    if (!_connectivity.isOnline) {
      final todos = await _offlineStore.lerCache('animais_${_client.auth.currentUser!.id}_todos_todos');
      final animais = todos is List
          ? todos.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      final indice = animais.indexWhere((item) => item['id']?.toString() == animalId);
      if (indice < 0) throw Exception('Carregue o cadastro do animal com internet antes de transferi-lo offline.');
      if (animais[indice]['rebanho_id']?.toString() != rebanhoOrigemId) {
        throw Exception('O rebanho atual do animal mudou. Atualize os dados quando houver internet.');
      }
      final rebanhos = await RebanhoService().getRebanhos(somenteAtivos: true);
      if (!rebanhos.any((item) => item['id']?.toString() == rebanhoDestinoId)) {
        throw Exception('O lote de destino precisa estar carregado e ativo no aparelho.');
      }
      final registroId = const Uuid().v4();
      final agora = DateTime.now().toUtc().toIso8601String();
      final historico = <String, dynamic>{
        'id': registroId,
        'animal_id': animalId,
        'fazenda_id': fazendaId,
        'rebanho_origem_id': rebanhoOrigemId,
        'rebanho_destino_id': rebanhoDestinoId,
        'data_transferencia': (dataTransferencia ?? DateTime.now()).toUtc().toIso8601String(),
        'observacao': _valorOuNull(observacao),
        'criado_em': agora,
      };
      await OfflineSyncService.instance.enfileirar(tipo: 'animal.transferir', dados: historico);
      await _salvarHistoricoLocal(fazendaId, animalId, historico);
      await _atualizarAnimalLocal(animais[indice], rebanhoDestinoId);
      await _atualizarContagemRebanhos(rebanhoOrigemId, rebanhoDestinoId);
      return true;
    }

    final animal = await _client
        .from('animais')
        .select('id, rebanho_id, fazenda_id')
        .eq('id', animalId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (animal == null) {
      throw Exception('Animal não encontrado na fazenda atual.');
    }

    final rebanhoAtualId = animal['rebanho_id']?.toString();

    if (rebanhoAtualId != rebanhoOrigemId) {
      throw Exception(
        'O rebanho atual do animal mudou. Atualize a tela e tente novamente.',
      );
    }

    final destino = await _client
        .from('rebanhos')
        .select('id, ativo')
        .eq('id', rebanhoDestinoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (destino == null) {
      throw Exception('Rebanho de destino não encontrado.');
    }

    if (destino['ativo'] != true) {
      throw Exception('O rebanho de destino está inativo.');
    }

    final origem = await _client
        .from('rebanhos')
        .select('id')
        .eq('id', rebanhoOrigemId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (origem == null) {
      throw Exception('Rebanho de origem não encontrado.');
    }

    final dadosHistorico = <String, dynamic>{
      'animal_id': animalId,
      'fazenda_id': fazendaId,
      'rebanho_origem_id': rebanhoOrigemId,
      'rebanho_destino_id': rebanhoDestinoId,
      'data_transferencia': (dataTransferencia ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'observacao': _valorOuNull(observacao),
    };

    final salvo = await _client
        .from('animal_transferencias')
        .insert(dadosHistorico)
        .select('id, animal_id, fazenda_id, rebanho_origem_id, rebanho_destino_id, data_transferencia, observacao, criado_em')
        .single();

    await _client
        .from('animais')
        .update({
          'rebanho_id': rebanhoDestinoId,
          'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', animalId)
        .eq('fazenda_id', fazendaId);
    await _salvarHistoricoLocal(fazendaId, animalId, Map<String, dynamic>.from(salvo));
    await _atualizarAnimalLocal(
      {'id': animalId, 'rebanho_id': rebanhoOrigemId, 'status': 'ativo'},
      rebanhoDestinoId,
    );
    await _atualizarContagemRebanhos(rebanhoOrigemId, rebanhoDestinoId);
    return false;
  }

  String _historicoCacheKey(String fazendaId, String animalId) => 'animal_transferencias_${fazendaId}_$animalId';

  Future<void> _salvarHistoricoLocal(String fazendaId, String animalId, Map<String, dynamic> item) async {
    final chave = _historicoCacheKey(fazendaId, animalId);
    final cache = await _offlineStore.lerCache(chave);
    final lista = cache is List
        ? cache.whereType<Map>().map((linha) => Map<String, dynamic>.from(linha)).toList()
        : <Map<String, dynamic>>[];
    lista.removeWhere((linha) => linha['id']?.toString() == item['id']?.toString());
    lista.insert(0, Map<String, dynamic>.from(item));
    await _offlineStore.salvarCache(chave, lista);
  }

  Future<void> _atualizarAnimalLocal(Map<String, dynamic> animal, String destinoId) async {
    final usuarioId = _client.auth.currentUser!.id;
    final origemId = animal['rebanho_id']?.toString();
    for (final tipo in ['todos', 'ativos']) {
      for (final loteId in <String?>{null, origemId, destinoId}) {
        final chave = 'animais_${usuarioId}_${tipo}_${loteId ?? 'todos'}';
        final cache = await _offlineStore.lerCache(chave);
        if (cache is! List) continue;
        final lista = cache.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        final correspondentes = lista.where((item) => item['id']?.toString() == animal['id']?.toString()).toList();
        final existente = correspondentes.isEmpty ? null : correspondentes.first;
        final atualizado = <String, dynamic>{
          ...animal,
          if (existente != null) ...existente,
          'rebanho_id': destinoId,
          'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        };
        lista.removeWhere((item) => item['id']?.toString() == animal['id']?.toString());
        final pertenceAoTipo = tipo != 'ativos' || atualizado['status'] == 'ativo';
        if ((loteId == null || loteId == destinoId) && pertenceAoTipo) {
          lista.add(atualizado);
        }
        await _offlineStore.salvarCache(chave, lista);
      }
    }
  }

  Future<void> _atualizarContagemRebanhos(String origemId, String destinoId) async {
    for (final chave in ['rebanhos_ativos', 'rebanhos_todos']) {
      final cache = await _offlineStore.lerCache(chave);
      if (cache is! List) continue;
      final lista = cache.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      for (final rebanho in lista) {
        final id = rebanho['id']?.toString();
        final quantidade = (rebanho['quantidade_animais'] as num?)?.toInt();
        if (quantidade == null) continue;
        if (id == origemId) rebanho['quantidade_animais'] = (quantidade - 1).clamp(0, 1 << 31);
        if (id == destinoId) rebanho['quantidade_animais'] = quantidade + 1;
      }
      await _offlineStore.salvarCache(chave, lista);
    }
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
}
