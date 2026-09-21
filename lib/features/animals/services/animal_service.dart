import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class AnimalService {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<Map<String, dynamic>>> getAnimaisAtivos() async {
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

    if (fazenda == null) {
      return [];
    }

    final animais = await _client
        .from('animais')
        .select()
        .eq('fazenda_id', fazenda['id'])
        .eq('status', 'ativo');

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
}
