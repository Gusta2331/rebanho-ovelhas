import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';
import '../models/manejo.dart';

class ManejoService {
  SupabaseClient get _client => SupabaseService.client;

  Future<String> _getMinhaFazendaId() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) throw Exception('Usuário não autenticado.');

    final fazenda = await _client.from('fazendas')
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

  Future<List<Map<String, dynamic>>> getManejos() async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('manejos')
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
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (tipo == TipoManejo.famacha &&
        (famachaEscore == null || famachaEscore < 1 || famachaEscore > 5)) {
      throw Exception('Informe uma classificação FAMACHA de 1 a 5.');
    }

    if (tipo != TipoManejo.famacha && famachaEscore != null) {
      throw Exception('A classificação FAMACHA só pode ser usada em uma avaliação FAMACHA.');
    }

    final animal = await _client.from('animais')
        .select('id')
        .eq('id', animalId)
        .eq('fazenda_id', fazendaId)
        .eq('status', 'ativo')
        .maybeSingle();

    if (animal == null) {
      throw Exception('O animal selecionado não está ativo ou não pertence à fazenda.');
    }

    final dados = <String, dynamic>{
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'animal_id': animalId,
      'tipo': Manejo.tipoToString(tipo),
      'data': data.toIso8601String(),
      'famacha_escore': famachaEscore,
      'observacoes': observacoes?.trim().isEmpty == true ? null : observacoes?.trim(),
    };

    final resultado = await _client.from('manejos')
        .insert(dados)
        .select('*, animais(brinco, nome)')
        .single();

    return Map<String, dynamic>.from(resultado);
  }
}
