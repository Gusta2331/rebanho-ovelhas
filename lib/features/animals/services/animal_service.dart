import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class AnimalService {
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

  Future<List<Map<String, dynamic>>> getAnimaisAtivos() async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    final animais = await _client
        .from('animais')
        .select()
        .eq('fazenda_id', fazendaId)
        .eq('status', 'ativo')
        .order('brinco');

    return List<Map<String, dynamic>>.from(animais);
  }

  Future<List<Map<String, dynamic>>> getTodosAnimais() async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    final animais = await _client
        .from('animais')
        .select()
        .eq('fazenda_id', fazendaId)
        .order('brinco');

    return List<Map<String, dynamic>>.from(animais);
  }

  Future<int> getTotalAnimaisAtivos() async {
    final animais = await getAnimaisAtivos();

    return animais.length;
  }

  Future<int> getTotalFemeasAtivas() async {
    final animais = await getAnimaisAtivos();

    return animais.where((animal) => animal['sexo'] == 'femea').length;
  }

  Future<int> getTotalMachosAtivos() async {
    final animais = await getAnimaisAtivos();

    return animais.where((animal) => animal['sexo'] == 'macho').length;
  }

  Future<bool> brincoDisponivel({
    required int brinco,
    String? animalIdAtual,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return false;
    }

    var consulta = _client
        .from('animais')
        .select('id')
        .eq('fazenda_id', fazendaId)
        .eq('brinco', brinco);

    if (animalIdAtual != null) {
      consulta = consulta.neq('id', animalIdAtual);
    }

    final resultado = await consulta.maybeSingle();

    return resultado == null;
  }

  Future<int> getMenorBrincoDisponivel() async {
    final animais = await getTodosAnimais();

    final brincosUsados = <int>{};

    for (final animal in animais) {
      final brinco = animal['brinco'];

      if (brinco is int) {
        brincosUsados.add(brinco);
      } else if (brinco is num) {
        brincosUsados.add(brinco.toInt());
      }
    }

    var numero = 1;

    while (brincosUsados.contains(numero)) {
      numero++;
    }

    return numero;
  }

  Future<Map<String, dynamic>?> _buscarRacaPorNome(
    String nome,
    String fazendaId,
  ) async {
    final resultado = await _client
        .from('racas')
        .select('id, nome')
        .eq('fazenda_id', fazendaId)
        .eq('nome', nome.trim())
        .eq('ativo', true)
        .maybeSingle();

    return resultado;
  }

  Future<String?> _buscarRacaId({
    required String nome,
    required String fazendaId,
  }) async {
    if (nome.trim().isEmpty) {
      return null;
    }

    final raca = await _buscarRacaPorNome(nome, fazendaId);

    return raca?['id'] as String?;
  }

  Future<Map<String, dynamic>> criarAnimal({
    required int brinco,
    String? nome,
    required String sexo,
    required String raca,
    DateTime? dataNascimento,
    required String status,
    DateTime? dataEntrada,
    String? observacoes,
    String? fotoUrl,
    String? maeId,
    String? paiId,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final disponivel = await brincoDisponivel(brinco: brinco);

    if (!disponivel) {
      throw Exception('O brinco $brinco já foi utilizado por outro animal.');
    }

    final racaId = await _buscarRacaId(nome: raca, fazendaId: fazendaId);

    final dados = <String, dynamic>{
      'fazenda_id': fazendaId,
      'brinco': brinco,
      'nome': nome?.trim().isEmpty == true ? null : nome?.trim(),
      'sexo': sexo,
      'raca_id': racaId,
      'data_nascimento': dataNascimento?.toIso8601String(),
      'status': status,
      'data_entrada': dataEntrada?.toIso8601String(),
      'observacoes': observacoes?.trim().isEmpty == true
          ? null
          : observacoes?.trim(),
      'foto_url': fotoUrl?.trim().isEmpty == true ? null : fotoUrl?.trim(),
      'mae_id': maeId,
      'pai_id': paiId,
    };

    final resultado = await _client
        .from('animais')
        .insert(dados)
        .select()
        .single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<Map<String, dynamic>> atualizarAnimal({
    required String id,
    required int brinco,
    String? nome,
    required String sexo,
    required String raca,
    DateTime? dataNascimento,
    required String status,
    DateTime? dataEntrada,
    DateTime? dataSaida,
    String? observacoes,
    String? fotoUrl,
    String? maeId,
    String? paiId,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final disponivel = await brincoDisponivel(
      brinco: brinco,
      animalIdAtual: id,
    );

    if (!disponivel) {
      throw Exception('O brinco $brinco já foi utilizado por outro animal.');
    }

    final racaId = await _buscarRacaId(nome: raca, fazendaId: fazendaId);

    final dados = <String, dynamic>{
      'brinco': brinco,
      'nome': nome?.trim().isEmpty == true ? null : nome?.trim(),
      'sexo': sexo,
      'raca_id': racaId,
      'data_nascimento': dataNascimento?.toIso8601String(),
      'status': status,
      'data_entrada': dataEntrada?.toIso8601String(),
      'data_saida': dataSaida?.toIso8601String(),
      'observacoes': observacoes?.trim().isEmpty == true
          ? null
          : observacoes?.trim(),
      'foto_url': fotoUrl?.trim().isEmpty == true ? null : fotoUrl?.trim(),
      'mae_id': maeId,
      'pai_id': paiId,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };

    final resultado = await _client
        .from('animais')
        .update(dados)
        .eq('id', id)
        .eq('fazenda_id', fazendaId)
        .select()
        .single();

    return Map<String, dynamic>.from(resultado);
  }
}
