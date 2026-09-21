import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class RebanhoService {
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

  Future<List<Map<String, dynamic>>> getRebanhos({
    bool somenteAtivos = false,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
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
      'fazenda_id': fazendaId,
      'nome': nomeNormalizado,
      'descricao': _valorOuNull(descricao),
      'finalidade': _valorOuNull(finalidade),
      'localizacao': _valorOuNull(localizacao),
      'ativo': true,
    };

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

    await _client
        .from('rebanhos')
        .update({
          'ativo': ativo,
          'atualizado_em': DateTime.now().toUtc().toIso8601String(),
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
}
