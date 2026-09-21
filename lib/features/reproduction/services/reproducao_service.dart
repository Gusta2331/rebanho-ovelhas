import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../models/monta.dart';
import '../models/reproducao.dart';
import '../models/reproducao_nascimento.dart';

class ReproducaoService {
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

  // ============================================================
  // REPRODUÇÕES
  // ============================================================

  Future<List<Reproducao>> getReproducoes() async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    final resultado = await _client
        .from('reproducoes')
        .select('''
          id,
          fazenda_id,
          mae_id,
          pai_id,
          data_cobertura,
          data_previsao_parto,
          data_parto,
          status,
          observacoes,
          criado_em,
          atualizado_em
        ''')
        .eq('fazenda_id', fazendaId)
        .order('criado_em', ascending: false);

    return resultado
        .map((item) => Reproducao.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Reproducao?> getReproducaoPorId(String reproducaoId) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return null;
    }

    final resultado = await _client
        .from('reproducoes')
        .select('''
          id,
          fazenda_id,
          mae_id,
          pai_id,
          data_cobertura,
          data_previsao_parto,
          data_parto,
          status,
          observacoes,
          criado_em,
          atualizado_em
        ''')
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (resultado == null) {
      return null;
    }

    return Reproducao.fromMap(Map<String, dynamic>.from(resultado));
  }

  Future<Reproducao> criarReproducao({
    required String maeId,
    String? paiId,
    DateTime? dataCobertura,
    DateTime? dataPrevisaoParto,
    String status = 'planejada',
    String? observacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    if (paiId != null && maeId == paiId) {
      throw Exception('A mãe e o pai precisam ser animais diferentes.');
    }

    final mae = await _client
        .from('animais')
        .select('id, sexo, fazenda_id, status')
        .eq('id', maeId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (mae == null) {
      throw Exception('A ovelha selecionada não foi encontrada.');
    }

    if (mae['sexo'] != 'femea') {
      throw Exception('A mãe selecionada precisa ser uma fêmea.');
    }

    Map<String, dynamic>? pai;

    if (paiId != null) {
      pai = await _client
          .from('animais')
          .select('id, sexo, fazenda_id, status')
          .eq('id', paiId)
          .eq('fazenda_id', fazendaId)
          .maybeSingle();

      if (pai == null) {
        throw Exception('O carneiro selecionado não foi encontrado.');
      }

      if (pai['sexo'] != 'macho') {
        throw Exception('O pai selecionado precisa ser um macho.');
      }
    }

    final dados = <String, dynamic>{
      'fazenda_id': fazendaId,
      'mae_id': maeId,
      'pai_id': paiId,
      'data_cobertura': _dateOnlyOrNull(dataCobertura),
      'data_previsao_parto': _dateOnlyOrNull(dataPrevisaoParto),
      'status': status,
      'observacoes': _valorOuNull(observacoes),
    };

    final resultado = await _client.from('reproducoes').insert(dados).select('''
          id,
          fazenda_id,
          mae_id,
          pai_id,
          data_cobertura,
          data_previsao_parto,
          data_parto,
          status,
          observacoes,
          criado_em,
          atualizado_em
        ''').single();

    return Reproducao.fromMap(Map<String, dynamic>.from(resultado));
  }

  Future<Reproducao> atualizarReproducao({
    required String reproducaoId,
    required String maeId,
    String? paiId,
    DateTime? dataCobertura,
    DateTime? dataPrevisaoParto,
    DateTime? dataParto,
    required String status,
    String? observacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    if (paiId != null && maeId == paiId) {
      throw Exception('A mãe e o pai precisam ser animais diferentes.');
    }

    await _validarMaeEPai(fazendaId: fazendaId, maeId: maeId, paiId: paiId);

    final dados = <String, dynamic>{
      'mae_id': maeId,
      'pai_id': paiId,
      'data_cobertura': _dateOnlyOrNull(dataCobertura),
      'data_previsao_parto': _dateOnlyOrNull(dataPrevisaoParto),
      'data_parto': _dateOnlyOrNull(dataParto),
      'status': status,
      'observacoes': _valorOuNull(observacoes),
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };

    final resultado = await _client
        .from('reproducoes')
        .update(dados)
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .select('''
          id,
          fazenda_id,
          mae_id,
          pai_id,
          data_cobertura,
          data_previsao_parto,
          data_parto,
          status,
          observacoes,
          criado_em,
          atualizado_em
        ''')
        .single();

    return Reproducao.fromMap(Map<String, dynamic>.from(resultado));
  }

  Future<void> excluirReproducao(String reproducaoId) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final nascimentos = await _client
        .from('reproducao_nascimentos')
        .select('id')
        .eq('reproducao_id', reproducaoId);

    if (nascimentos.isNotEmpty) {
      throw Exception(
        'Não é possível excluir uma reprodução que possui '
        'nascimentos registrados.',
      );
    }

    final montas = await _client
        .from('reproducao_coberturas')
        .select('id')
        .eq('reproducao_id', reproducaoId);

    if (montas.isNotEmpty) {
      throw Exception(
        'Não é possível excluir uma reprodução que possui '
        'montas registradas.',
      );
    }

    await _client
        .from('reproducoes')
        .delete()
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId);
  }

  // ============================================================
  // MONTAS
  // ============================================================

  Future<List<Monta>> getMontas(String reproducaoId) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    final reproducao = await _client
        .from('reproducoes')
        .select('id')
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (reproducao == null) {
      throw Exception('Reprodução não encontrada.');
    }

    final resultado = await _client
        .from('reproducao_coberturas')
        .select('''
          id,
          reproducao_id,
          carneiro_id,
          data_cobertura,
          observacoes,
          criado_em
        ''')
        .eq('reproducao_id', reproducaoId)
        .order('data_cobertura', ascending: false);

    return resultado
        .map((item) => Monta.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Monta> criarMonta({
    required String reproducaoId,
    required String carneiroId,
    required DateTime dataMonta,
    String? observacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final reproducao = await _client
        .from('reproducoes')
        .select('id, fazenda_id')
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (reproducao == null) {
      throw Exception('Reprodução não encontrada.');
    }

    final carneiro = await _client
        .from('animais')
        .select('id, sexo, fazenda_id, status')
        .eq('id', carneiroId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (carneiro == null) {
      throw Exception('O carneiro selecionado não foi encontrado.');
    }

    if (carneiro['sexo'] != 'macho') {
      throw Exception('O animal selecionado não é um carneiro.');
    }

    if (carneiro['status'] != 'ativo') {
      throw Exception('O carneiro selecionado não está ativo.');
    }

    final dados = <String, dynamic>{
      'reproducao_id': reproducaoId,
      'carneiro_id': carneiroId,
      'data_cobertura': _dateOnly(dataMonta),
      'observacoes': _valorOuNull(observacoes),
    };

    final resultado = await _client
        .from('reproducao_coberturas')
        .insert(dados)
        .select('''
          id,
          reproducao_id,
          carneiro_id,
          data_cobertura,
          observacoes,
          criado_em
        ''')
        .single();

    return Monta.fromMap(Map<String, dynamic>.from(resultado));
  }

  Future<Monta> atualizarMonta({
    required String montaId,
    required String reproducaoId,
    required String carneiroId,
    required DateTime dataMonta,
    String? observacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final reproducao = await _client
        .from('reproducoes')
        .select('id')
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (reproducao == null) {
      throw Exception('Reprodução não encontrada.');
    }

    final carneiro = await _client
        .from('animais')
        .select('id, sexo, status')
        .eq('id', carneiroId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (carneiro == null) {
      throw Exception('O carneiro selecionado não foi encontrado.');
    }

    if (carneiro['sexo'] != 'macho') {
      throw Exception('O animal selecionado não é um macho.');
    }

    if (carneiro['status'] != 'ativo') {
      throw Exception('O carneiro selecionado não está ativo.');
    }

    final dados = <String, dynamic>{
      'carneiro_id': carneiroId,
      'data_cobertura': _dateOnly(dataMonta),
      'observacoes': _valorOuNull(observacoes),
    };

    final resultado = await _client
        .from('reproducao_coberturas')
        .update(dados)
        .eq('id', montaId)
        .eq('reproducao_id', reproducaoId)
        .select('''
          id,
          reproducao_id,
          carneiro_id,
          data_cobertura,
          observacoes,
          criado_em
        ''')
        .single();

    return Monta.fromMap(Map<String, dynamic>.from(resultado));
  }

  Future<void> excluirMonta({
    required String montaId,
    required String reproducaoId,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final reproducao = await _client
        .from('reproducoes')
        .select('id')
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (reproducao == null) {
      throw Exception('Reprodução não encontrada.');
    }

    await _client
        .from('reproducao_coberturas')
        .delete()
        .eq('id', montaId)
        .eq('reproducao_id', reproducaoId);
  }

  // ============================================================
  // NASCIMENTOS
  // ============================================================

  Future<List<ReproducaoNascimento>> getNascimentos(String reproducaoId) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    final reproducao = await _client
        .from('reproducoes')
        .select('id')
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (reproducao == null) {
      throw Exception('Reprodução não encontrada.');
    }

    final resultado = await _client
        .from('reproducao_nascimentos')
        .select('''
          id,
          reproducao_id,
          animal_id,
          sexo,
          data_nascimento,
          observacoes,
          criado_em
        ''')
        .eq('reproducao_id', reproducaoId)
        .order('data_nascimento');

    return resultado
        .map(
          (item) =>
              ReproducaoNascimento.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<ReproducaoNascimento> registrarNascimento({
    required String reproducaoId,
    required String animalId,
    required String sexo,
    required DateTime dataNascimento,
    String? observacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    if (sexo != 'femea' && sexo != 'macho') {
      throw Exception('Sexo do nascimento inválido.');
    }

    final reproducao = await _client
        .from('reproducoes')
        .select('id, fazenda_id, mae_id, pai_id')
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (reproducao == null) {
      throw Exception('Reprodução não encontrada.');
    }

    final animal = await _client
        .from('animais')
        .select('id, fazenda_id')
        .eq('id', animalId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (animal == null) {
      throw Exception('O animal selecionado não foi encontrado.');
    }

    final nascimentoExistente = await _client
        .from('reproducao_nascimentos')
        .select('id')
        .eq('animal_id', animalId)
        .maybeSingle();

    if (nascimentoExistente != null) {
      throw Exception('Este animal já está vinculado a um nascimento.');
    }

    final dados = <String, dynamic>{
      'reproducao_id': reproducaoId,
      'animal_id': animalId,
      'sexo': sexo,
      'data_nascimento': _dateOnly(dataNascimento),
      'observacoes': _valorOuNull(observacoes),
    };

    final resultado = await _client
        .from('reproducao_nascimentos')
        .insert(dados)
        .select('''
          id,
          reproducao_id,
          animal_id,
          sexo,
          data_nascimento,
          observacoes,
          criado_em
        ''')
        .single();

    return ReproducaoNascimento.fromMap(Map<String, dynamic>.from(resultado));
  }

  Future<void> excluirNascimento({
    required String nascimentoId,
    required String reproducaoId,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final reproducao = await _client
        .from('reproducoes')
        .select('id')
        .eq('id', reproducaoId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (reproducao == null) {
      throw Exception('Reprodução não encontrada.');
    }

    await _client
        .from('reproducao_nascimentos')
        .delete()
        .eq('id', nascimentoId)
        .eq('reproducao_id', reproducaoId);
  }

  // ============================================================
  // VALIDAÇÕES AUXILIARES
  // ============================================================

  Future<void> _validarMaeEPai({
    required String fazendaId,
    required String maeId,
    String? paiId,
  }) async {
    final mae = await _client
        .from('animais')
        .select('id, sexo, fazenda_id')
        .eq('id', maeId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (mae == null) {
      throw Exception('A ovelha selecionada não foi encontrada.');
    }

    if (mae['sexo'] != 'femea') {
      throw Exception('A mãe selecionada precisa ser uma fêmea.');
    }

    if (paiId == null) {
      return;
    }

    final pai = await _client
        .from('animais')
        .select('id, sexo, fazenda_id')
        .eq('id', paiId)
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (pai == null) {
      throw Exception('O carneiro selecionado não foi encontrado.');
    }

    if (pai['sexo'] != 'macho') {
      throw Exception('O pai selecionado precisa ser um macho.');
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

  String? _dateOnlyOrNull(DateTime? data) {
    if (data == null) {
      return null;
    }

    return _dateOnly(data);
  }

  String _dateOnly(DateTime data) {
    final dataLocal = DateTime(data.year, data.month, data.day);

    return dataLocal.toIso8601String().split('T').first;
  }
}
