import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class AnimalTransferService {
  SupabaseClient get _client => SupabaseService.client;

  Future<String?> _getMinhaFazendaId() async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    final fazenda = await _client
        .from('fazendas')
        .select('id')
        .eq('proprietario_id', usuario.id)
        .eq('ativo', true)
        .maybeSingle();

    return fazenda?['id'] as String?;
  }

  Future<List<Map<String, dynamic>>> getRebanhosDisponiveis({
    required String rebanhoAtualId,
  }) async {
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

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<void> transferirAnimal({
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

    await _client.from('animal_transferencias').insert(dadosHistorico);

    await _client
        .from('animais')
        .update({
          'rebanho_id': rebanhoDestinoId,
          'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', animalId)
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
}
