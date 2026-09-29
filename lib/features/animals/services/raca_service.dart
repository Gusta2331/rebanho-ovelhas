import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../data/racas.dart';

class RacaService {
  final SupabaseClient _client = SupabaseService.client;

  Future<String?> _fazendaId() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) return null;
    final fazenda = await _client
        .from('fazendas')
        .select('id')
        .eq('proprietario_id', usuario.id)
        .eq('ativo', true)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return fazenda?['id']?.toString();
  }

  Future<List<Raca>> listar() async {
    final fazendaId = await _fazendaId();
    if (fazendaId == null) throw Exception('Nenhuma fazenda ativa foi encontrada.');
    await _garantirRacasPadrao(fazendaId);
    final resposta = await _client
        .from('racas')
        .select('id, nome')
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .order('nome');
    return (resposta as List)
        .map((item) => Raca(id: item['id'].toString(), nome: item['nome'].toString()))
        .toList();
  }

  Future<void> adicionar(String nome) async {
    final fazendaId = await _fazendaId();
    if (fazendaId == null) throw Exception('Nenhuma fazenda ativa foi encontrada.');
    final nomeNormalizado = nome.trim();
    if (nomeNormalizado.isEmpty) throw Exception('Informe o nome da raça.');
    final existente = await _client.from('racas').select('id')
        .eq('fazenda_id', fazendaId).ilike('nome', nomeNormalizado)
        .eq('ativo', true).maybeSingle();
    if (existente != null) throw Exception('Essa raça já está cadastrada.');
    await _client.from('racas').insert({
      'fazenda_id': fazendaId, 'nome': nomeNormalizado, 'ativo': true,
    });
  }

  Future<void> editar(Raca raca, String novoNome) async {
    final fazendaId = await _fazendaId();
    if (fazendaId == null) throw Exception('Nenhuma fazenda ativa foi encontrada.');
    final nome = novoNome.trim();
    if (nome.isEmpty) throw Exception('Informe o nome da raça.');
    final existente = await _client.from('racas').select('id')
        .eq('fazenda_id', fazendaId).ilike('nome', nome)
        .eq('ativo', true).neq('id', raca.id).maybeSingle();
    if (existente != null) throw Exception('Essa raça já está cadastrada.');
    await _client.from('racas').update({'nome': nome})
        .eq('id', raca.id).eq('fazenda_id', fazendaId);
  }

  Future<void> excluir(Raca raca) async {
    final fazendaId = await _fazendaId();
    if (fazendaId == null) throw Exception('Nenhuma fazenda ativa foi encontrada.');
    final uso = await _client.from('animais').select('id')
        .eq('fazenda_id', fazendaId).eq('raca_id', raca.id).limit(1);
    if ((uso as List).isNotEmpty) {
      throw Exception('Essa raça está vinculada a animais e não pode ser excluída.');
    }
    await _client.from('racas').update({'ativo': false})
        .eq('id', raca.id).eq('fazenda_id', fazendaId);
  }

  Future<void> _garantirRacasPadrao(String fazendaId) async {
    const padroes = ['Santa Inês', 'Dorper', 'White Dorper', 'Somalis', 'Morada Nova'];
    for (final nome in padroes) {
      final existente = await _client.from('racas').select('id')
          .eq('fazenda_id', fazendaId).ilike('nome', nome).maybeSingle();
      if (existente == null) {
        await _client.from('racas').insert({
          'fazenda_id': fazendaId, 'nome': nome, 'ativo': true,
        });
      } else {
        await _client.from('racas').update({'ativo': true})
            .eq('id', existente['id']).eq('fazenda_id', fazendaId);
      }
    }
  }
}