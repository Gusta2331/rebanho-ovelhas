import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/services/supabase_service.dart';
import '../models/manejo.dart';

class ManejoProgramadoService {
  SupabaseClient get _client => SupabaseService.client;
  final OfflineStore _offlineStore = OfflineStore();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  Future<String> _getMinhaFazendaId() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) throw Exception('Usuário não autenticado.');
    final fazenda = await _client.from('fazendas').select('id')
        .eq('proprietario_id', usuario.id).eq('ativo', true).maybeSingle();
    final id = fazenda?['id']?.toString();
    if (id == null || id.isEmpty) throw Exception('Nenhuma fazenda ativa foi encontrada.');
    return id;
  }

  Future<List<Map<String, dynamic>>> getProgramados() async {
    final fazendaId = await _getMinhaFazendaId();
    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('manejos_programados');
      if (cache is List) return cache.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return [];
    }
    final dados = await _client.from('manejos_programados')
        .select('*, manejos_programados_animais(animal_id, animais(brinco, nome))')
        .eq('fazenda_id', fazendaId)
        .order('concluido', ascending: true)
        .order('data_programada', ascending: true);
    final lista = List<Map<String, dynamic>>.from(dados);
    await _offlineStore.salvarCache('manejos_programados', lista);
    return lista;
  }

  Future<void> criar({required TipoManejo tipo, required DateTime dataProgramada,
      required List<String> animalIds, String? observacoes,
      String? vacinaId, String? vacinaNome, String? vacinaFabricante}) async {
    final fazendaId = await _getMinhaFazendaId();
    if (animalIds.isEmpty) throw Exception('Selecione pelo menos um animal.');
    final animais = await _client.from('animais').select('id')
        .eq('fazenda_id', fazendaId).eq('status', 'ativo').inFilter('id', animalIds);
    final idsValidos = List<Map<String, dynamic>>.from(animais)
        .map((a) => a['id'].toString()).toSet();
    if (idsValidos.length != animalIds.length ||
        animalIds.any((id) => !idsValidos.contains(id))) {
      throw Exception('Um ou mais animais não estão ativos ou não pertencem à fazenda.');
    }
    final id = const Uuid().v4();
    await _client.from('manejos_programados').insert({
      'id': id, 'fazenda_id': fazendaId, 'tipo': Manejo.tipoToString(tipo),
      'data_programada': dataProgramada.toIso8601String(),
      'observacoes': observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
      'vacina_id': tipo == TipoManejo.vacinacao ? vacinaId : null,
      'vacina_nome': tipo == TipoManejo.vacinacao ? vacinaNome?.trim() : null,
      'vacina_fabricante': tipo == TipoManejo.vacinacao ? vacinaFabricante?.trim() : null,
    });
    await _client.from('manejos_programados_animais').insert(
      animalIds.map((animalId) => {
        'id': const Uuid().v4(), 'manejo_programado_id': id, 'animal_id': animalId,
      }).toList(),
    );
  }

  Future<void> concluir(String id) async {
    final fazendaId = await _getMinhaFazendaId();
    await _client.from('manejos_programados').update({
      'concluido': true, 'realizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('fazenda_id', fazendaId);
  }

  Future<void> reprogramar(String id, DateTime data) async {
    final fazendaId = await _getMinhaFazendaId();
    await _client.from('manejos_programados').update({
      'data_programada': data.toIso8601String(), 'concluido': false, 'realizado_em': null,
    }).eq('id', id).eq('fazenda_id', fazendaId);
  }

  Future<void> excluir(String id) async {
    final fazendaId = await _getMinhaFazendaId();
    await _client.from('manejos_programados').delete()
        .eq('id', id).eq('fazenda_id', fazendaId);
  }
}
