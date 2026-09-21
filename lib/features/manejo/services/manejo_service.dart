import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';
import '../models/manejo.dart';

class ManejoService {
  SupabaseClient get _client => SupabaseService.client;

  Future<String> _getMinhaFazendaId() async {
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

    final id = fazenda?['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    return id;
  }

  Future<List<Map<String, dynamic>>> getVacinas() async {
    final fazendaId = await _getMinhaFazendaId();

    final resultado = await _client
        .from('vacinas')
        .select('id, nome, fabricante, ativo')
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .order('nome');

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarVacina({
    required String nome,
    String? fabricante,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    final nomeNormalizado = nome.trim();

    if (nomeNormalizado.isEmpty) {
      throw Exception('Informe o nome da vacina.');
    }

    final resultado = await _client
        .from('vacinas')
        .insert({
          'id': const Uuid().v4(),
          'fazenda_id': fazendaId,
          'nome': nomeNormalizado,
          'fabricante': fabricante?.trim().isEmpty == true
              ? null
              : fabricante?.trim(),
        })
        .select('id, nome, fabricante, ativo')
        .single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getManejos() async {
    final fazendaId = await _getMinhaFazendaId();

    final resultado = await _client
        .from('manejos')
        .select('*, animais(brinco, nome)')
        .eq('fazenda_id', fazendaId)
        .order('data', ascending: false);

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarManejo({
    required String animalId,
    required TipoManejo tipo,
    required DateTime data,
    int? famachaEscore,
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    _validarDados(
      tipo: tipo,
      famachaEscore: famachaEscore,
      vacinaId: vacinaId,
      vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote,
      outroNome: outroNome,
    );

    final animal = await _client
        .from('animais')
        .select('id')
        .eq('id', animalId)
        .eq('fazenda_id', fazendaId)
        .eq('status', 'ativo')
        .maybeSingle();

    if (animal == null) {
      throw Exception(
        'O animal selecionado não está ativo ou não pertence à fazenda.',
      );
    }

    final resultado = await _client
        .from('manejos')
        .insert(
          _dadosManejo(
            fazendaId: fazendaId,
            animalId: animalId,
            tipo: tipo,
            data: data,
            famachaEscore: famachaEscore,
            observacoes: observacoes,
            vacinaId: vacinaId,
            vacinaNome: vacinaNome,
            vacinaFabricante: vacinaFabricante,
            vacinaLote: vacinaLote,
            outroNome: outroNome,
          ),
        )
        .select('*, animais(brinco, nome)')
        .single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> criarManejosEmLote({
    required List<String> animalIds,
    required DateTime data,
    required TipoManejo tipo,
    Map<String, int> famachaPorAnimal = const {},
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (animalIds.isEmpty) {
      throw Exception('Selecione pelo menos um animal.');
    }

    if (tipo == TipoManejo.famacha) {
      final faltando = animalIds.any((id) {
        final escore = famachaPorAnimal[id];
        return escore == null || escore < 1 || escore > 5;
      });

      if (famachaPorAnimal.length != animalIds.length || faltando) {
        throw Exception('Informe o FAMACHA de todos os animais selecionados.');
      }
    }

    _validarDados(
      tipo: tipo,
      vacinaId: vacinaId,
      vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote,
    );

    final animais = await _client
        .from('animais')
        .select('id')
        .eq('fazenda_id', fazendaId)
        .eq('status', 'ativo')
        .inFilter('id', animalIds);

    final idsValidos = List<Map<String, dynamic>>.from(animais)
        .map((animal) => animal['id'].toString())
        .toSet();

    if (idsValidos.length != animalIds.length ||
        animalIds.any((id) => !idsValidos.contains(id))) {
      throw Exception(
        'Um ou mais animais selecionados não estão ativos ou não pertencem à fazenda.',
      );
    }

    final dados = animalIds.map((animalId) {
      return _dadosManejo(
        fazendaId: fazendaId,
        animalId: animalId,
        tipo: tipo,
        data: data,
        famachaEscore:
            tipo == TipoManejo.famacha ? famachaPorAnimal[animalId] : null,
        observacoes: observacoes,
        vacinaId: vacinaId,
        vacinaNome: vacinaNome,
        vacinaFabricante: vacinaFabricante,
        vacinaLote: vacinaLote,
        outroNome: outroNome,
      );
    }).toList();

    final resultado = await _client
        .from('manejos')
        .insert(dados)
        .select('*, animais(brinco, nome)');

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getHistoricoFamacha(
    String animalId,
  ) async {
    final fazendaId = await _getMinhaFazendaId();

    final resultado = await _client
        .from('manejos')
        .select('*, animais(brinco, nome)')
        .eq('fazenda_id', fazendaId)
        .eq('animal_id', animalId)
        .eq('tipo', 'famacha')
        .order('data', ascending: false);

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> getManejo(String id) async {
    final fazendaId = await _getMinhaFazendaId();

    final resultado = await _client
        .from('manejos')
        .select('*, animais(brinco, nome)')
        .eq('id', id)
        .eq('fazenda_id', fazendaId)
        .single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<void> atualizarManejo({
    required String id,
    required String animalId,
    required TipoManejo tipo,
    required DateTime data,
    int? famachaEscore,
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    _validarDados(
      tipo: tipo,
      famachaEscore: famachaEscore,
      vacinaId: vacinaId,
      vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote,
    );

    final animal = await _client
        .from('animais')
        .select('id')
        .eq('id', animalId)
        .eq('fazenda_id', fazendaId)
        .eq('status', 'ativo')
        .maybeSingle();

    if (animal == null) {
      throw Exception(
        'O animal selecionado não está ativo ou não pertence à fazenda.',
      );
    }

    await _client
        .from('manejos')
        .update({
          'animal_id': animalId,
          'tipo': Manejo.tipoToString(tipo),
          'data': data.toIso8601String(),
          'famacha_escore': tipo == TipoManejo.famacha ? famachaEscore : null,
          'observacoes':
              observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
          'vacina_id': tipo == TipoManejo.vacinacao ? vacinaId : null,
          'vacina_nome':
              tipo == TipoManejo.vacinacao ? vacinaNome?.trim() : null,
          'vacina_fabricante':
              tipo == TipoManejo.vacinacao ? vacinaFabricante?.trim() : null,
          'vacina_lote':
              tipo == TipoManejo.vacinacao ? vacinaLote?.trim() : null,
          'outro_nome': tipo == TipoManejo.outro ? outroNome?.trim() : null,
        })
        .eq('id', id)
        .eq('fazenda_id', fazendaId);
  }

  Future<void> excluirManejo(String id) async {
    final fazendaId = await _getMinhaFazendaId();

    await _client
        .from('manejos')
        .delete()
        .eq('id', id)
        .eq('fazenda_id', fazendaId);
  }

  void _validarDados({
    required TipoManejo tipo,
    int? famachaEscore,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
  }) {
    if (tipo == TipoManejo.famacha &&
        (famachaEscore == null ||
            famachaEscore < 1 ||
            famachaEscore > 5)) {
      throw Exception('Informe uma classificação FAMACHA de 1 a 5.');
    }

    if (tipo != TipoManejo.famacha && famachaEscore != null) {
      throw Exception(
        'A classificação FAMACHA só pode ser usada em uma avaliação FAMACHA.',
      );
    }

    if (tipo == TipoManejo.vacinacao &&
        (vacinaId == null &&
            (vacinaNome == null || vacinaNome.trim().isEmpty))) {
      throw Exception('Informe qual vacina foi aplicada.');
    }

    if (tipo == TipoManejo.outro &&
        (outroNome == null || outroNome.trim().isEmpty)) {
      throw Exception('Informe o nome do outro manejo.');
    }

    if (tipo != TipoManejo.outro && outroNome != null && outroNome.trim().isNotEmpty) {
      throw Exception('O nome personalizado só pode ser usado em Outro.');
    }

    if (tipo != TipoManejo.vacinacao &&
        (vacinaId != null ||
            vacinaNome != null ||
            vacinaFabricante != null ||
            vacinaLote != null)) {
      throw Exception(
        'Os dados da vacina só podem ser usados em uma vacinação.',
      );
    }
  }

  Map<String, dynamic> _dadosManejo({
    required String fazendaId,
    required String animalId,
    required TipoManejo tipo,
    required DateTime data,
    int? famachaEscore,
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
  }) {
    return {
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'animal_id': animalId,
      'tipo': Manejo.tipoToString(tipo),
      'data': data.toIso8601String(),
      'famacha_escore':
          tipo == TipoManejo.famacha ? famachaEscore : null,
      'observacoes':
          observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
      'vacina_id': tipo == TipoManejo.vacinacao ? vacinaId : null,
      'vacina_nome':
          tipo == TipoManejo.vacinacao ? vacinaNome?.trim() : null,
      'vacina_fabricante':
          tipo == TipoManejo.vacinacao ? vacinaFabricante?.trim() : null,
      'vacina_lote':
          tipo == TipoManejo.vacinacao ? vacinaLote?.trim() : null,
      'outro_nome': tipo == TipoManejo.outro ? outroNome?.trim() : null,
    };
  }
}
