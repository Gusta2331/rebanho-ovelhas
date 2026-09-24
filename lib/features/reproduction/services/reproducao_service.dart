import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/monta.dart';
import '../models/reproducao.dart';
import '../models/reproducao_nascimento.dart';
import '../../animals/services/animal_service.dart';

class ReproducaoService {
  SupabaseClient get _client => SupabaseService.client;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final OfflineStore _offlineStore = OfflineStore();

  Future<String?> _getMinhaFazendaId() async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    if (!_connectivity.isOnline) {
      final fazendaSalva =
          await _offlineStore.lerCache('fazenda_id_${usuario.id}') as String?;
      if (fazendaSalva != null) return fazendaSalva;
      return await _offlineStore.lerCache('rebanhos_fazenda_id') as String?;
    }
    final fazenda = await _client
        .from('fazendas')
        .select('id')
        .eq('proprietario_id', usuario.id)
        .eq('ativo', true)
        .maybeSingle();

    final id = fazenda?['id'] as String?;
    if (id != null)
      await _offlineStore.salvarCache('fazenda_id_${usuario.id}', id);
    return id;
  }

  // ============================================================
  // REPRODUÇÕES
  // ============================================================

  Future<List<Reproducao>> getReproducoes() async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('reproducoes_$fazendaId');
      if (cache is! List) return [];
      return cache
          .whereType<Map>()
          .map((item) => Reproducao.fromMap(Map<String, dynamic>.from(item)))
          .toList();
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
          data_confirmacao_prenhez,
          data_parto,
          status,
          observacoes,
          criado_em,
          atualizado_em
        ''')
        .eq('fazenda_id', fazendaId)
        .order('criado_em', ascending: false);

    final lista = resultado
        .map((item) => Reproducao.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    await _offlineStore.salvarCache(
      'reproducoes_$fazendaId',
      lista.map((item) => item.toMap()).toList(),
    );
    return lista;
  }

  Future<Reproducao?> getReproducaoPorId(String reproducaoId) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return null;
    }

    if (!_connectivity.isOnline) {
      final lista = await getReproducoes();
      for (final item in lista) {
        if (item.id == reproducaoId) return item;
      }
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
          data_confirmacao_prenhez,
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
    DateTime? dataConfirmacaoPrenhez,
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
    if (status == 'prenhe' && dataConfirmacaoPrenhez == null) {
      throw Exception('Informe a data de confirmação da prenhez.');
    }
    if (!_connectivity.isOnline) {
      final animais = await AnimalService().getAnimaisAtivos();
      Map<String, dynamic>? mae;
      for (final item in animais) {
        if (item['id']?.toString() == maeId) {
          mae = item;
          break;
        }
      }
      if (mae == null || mae['sexo']?.toString() != 'femea') {
        throw Exception('A mãe precisa estar salva no aparelho como fêmea.');
      }
      if (paiId != null &&
          !animais.any(
            (item) =>
                item['id']?.toString() == paiId &&
                item['sexo']?.toString() == 'macho',
          )) {
        throw Exception('O pai precisa estar salvo no aparelho como macho.');
      }
      final dadosLocais = {
        'id': const Uuid().v4(),
        'fazenda_id': fazendaId,
        'mae_id': maeId,
        'pai_id': paiId,
        'data_cobertura': _dateOnlyOrNull(dataCobertura),
        'data_previsao_parto': _dateOnlyOrNull(dataPrevisaoParto),
        'data_confirmacao_prenhez': _dateOnlyOrNull(dataConfirmacaoPrenhez),
        'data_parto': null,
        'status': status,
        'observacoes': _valorOuNull(observacoes),
        'criado_em': DateTime.now().toUtc().toIso8601String(),
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      };
      await OfflineSyncService.instance.enfileirar(
        tipo: 'reproducao.criar',
        dados: dadosLocais,
      );
      await _adicionarReproducaoAoCache(fazendaId, dadosLocais);
      return Reproducao.fromMap(dadosLocais);
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

    if (mae['status'] != 'ativo') {
      throw Exception('A ovelha selecionada não está ativa.');
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

      if (pai['status'] != 'ativo') {
        throw Exception('O carneiro selecionado não está ativo.');
      }
    }

    final dados = <String, dynamic>{
      'fazenda_id': fazendaId,
      'mae_id': maeId,
      'pai_id': paiId,
      'data_cobertura': _dateOnlyOrNull(dataCobertura),
      'data_previsao_parto': _dateOnlyOrNull(dataPrevisaoParto),
      'data_confirmacao_prenhez': _dateOnlyOrNull(dataConfirmacaoPrenhez),
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
          data_confirmacao_prenhez,
          data_parto,
          status,
          observacoes,
          criado_em,
          atualizado_em
        ''').single();

    return Reproducao.fromMap(Map<String, dynamic>.from(resultado));
  }

  Future<void> _adicionarReproducaoAoCache(
    String fazendaId,
    Map<String, dynamic> dados,
  ) async {
    final cache = await _offlineStore.lerCache('reproducoes_$fazendaId');
    final lista = cache is List
        ? cache
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    lista.removeWhere(
      (item) => item['id']?.toString() == dados['id']?.toString(),
    );
    lista.add(Map<String, dynamic>.from(dados));
    await _offlineStore.salvarCache('reproducoes_$fazendaId', lista);
  }

  Future<Reproducao> atualizarReproducao({
    required String reproducaoId,
    required String maeId,
    String? paiId,
    DateTime? dataCobertura,
    DateTime? dataPrevisaoParto,
    DateTime? dataConfirmacaoPrenhez,
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
    if (status == 'prenhe' && dataConfirmacaoPrenhez == null) {
      throw Exception('Informe a data de confirmação da prenhez.');
    }
    if (status == 'parto_realizado' && dataParto == null) {
      throw Exception('Informe a data do parto realizado.');
    }

    if (!_connectivity.isOnline) {
      final animais = await AnimalService().getAnimaisAtivos();
      if (!animais.any(
        (item) =>
            item['id']?.toString() == maeId &&
            item['sexo']?.toString() == 'femea',
      )) {
        throw Exception('A mãe precisa estar salva no aparelho como fêmea.');
      }
      if (paiId != null &&
          !animais.any(
            (item) =>
                item['id']?.toString() == paiId &&
                item['sexo']?.toString() == 'macho',
          )) {
        throw Exception('O pai precisa estar salvo no aparelho como macho.');
      }
      final dados = {
        'id': reproducaoId,
        'fazenda_id': fazendaId,
        'mae_id': maeId,
        'pai_id': paiId,
        'data_cobertura': _dateOnlyOrNull(dataCobertura),
        'data_previsao_parto': _dateOnlyOrNull(dataPrevisaoParto),
        'data_confirmacao_prenhez': _dateOnlyOrNull(dataConfirmacaoPrenhez),
        'data_parto': _dateOnlyOrNull(dataParto),
        'status': status,
        'observacoes': _valorOuNull(observacoes),
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      };
      await OfflineSyncService.instance.enfileirar(
        tipo: 'reproducao.atualizar',
        dados: dados,
      );
      await _adicionarReproducaoAoCache(fazendaId, dados);
      return Reproducao.fromMap(dados);
    }

    await _validarMaeEPai(fazendaId: fazendaId, maeId: maeId, paiId: paiId);

    final dados = <String, dynamic>{
      'mae_id': maeId,
      'pai_id': paiId,
      'data_cobertura': _dateOnlyOrNull(dataCobertura),
      'data_previsao_parto': _dateOnlyOrNull(dataPrevisaoParto),
      'data_confirmacao_prenhez': _dateOnlyOrNull(dataConfirmacaoPrenhez),
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
          data_confirmacao_prenhez,
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

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(
        'reproducao_montas_${fazendaId}_$reproducaoId',
      );
      if (cache is! List) return [];
      return cache
          .whereType<Map>()
          .map((item) => Monta.fromMap(Map<String, dynamic>.from(item)))
          .toList();
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

    final lista = resultado
        .map((item) => Monta.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    await _offlineStore.salvarCache(
      'reproducao_montas_${fazendaId}_$reproducaoId',
      lista.map((item) => item.toMap()).toList(),
    );
    return lista;
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

    if (!_connectivity.isOnline) {
      final reproducao = await getReproducaoPorId(reproducaoId);
      if (reproducao == null) {
        throw Exception('A reprodução precisa estar carregada no aparelho.');
      }
      final animais = await AnimalService().getAnimaisAtivos();
      if (!animais.any(
        (item) =>
            item['id']?.toString() == carneiroId &&
            item['sexo']?.toString() == 'macho',
      )) {
        throw Exception(
          'O carneiro precisa estar carregado no aparelho como macho ativo.',
        );
      }
      final dados = <String, dynamic>{
        'id': const Uuid().v4(),
        'reproducao_id': reproducaoId,
        'carneiro_id': carneiroId,
        'data_cobertura': _dateOnly(dataMonta),
        'observacoes': _valorOuNull(observacoes),
        'criado_em': DateTime.now().toUtc().toIso8601String(),
      };
      await OfflineSyncService.instance.enfileirar(
        tipo: 'reproducao.monta',
        dados: {...dados, 'fazenda_id': fazendaId},
      );
      final chave = 'reproducao_montas_${fazendaId}_$reproducaoId';
      final cache = await _offlineStore.lerCache(chave);
      final lista = cache is List
          ? cache
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      lista.removeWhere((item) => item['id']?.toString() == dados['id']);
      lista.insert(0, dados);
      await _offlineStore.salvarCache(chave, lista);
      if (reproducao.status == StatusReproducao.planejada) {
        await atualizarReproducao(
          reproducaoId: reproducaoId,
          maeId: reproducao.maeId,
          paiId: reproducao.paiId,
          dataCobertura: reproducao.dataCobertura ?? dataMonta,
          dataPrevisaoParto:
              reproducao.dataPrevisaoParto ??
              dataMonta.add(const Duration(days: 146)),
          dataParto: reproducao.dataParto,
          status: 'coberta',
          observacoes: reproducao.observacoes,
        );
      }
      return Monta.fromMap(dados);
    }

    final reproducao = await _client
        .from('reproducoes')
        .select('id, fazenda_id, status, data_cobertura, data_previsao_parto')
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

    if (reproducao['status'] == 'planejada') {
      final atualizacao = <String, dynamic>{
        'status': 'coberta',
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      };

      if (reproducao['data_cobertura'] == null) {
        atualizacao['data_cobertura'] = _dateOnly(dataMonta);
      }

      if (reproducao['data_previsao_parto'] == null) {
        atualizacao['data_previsao_parto'] = _dateOnly(
          dataMonta.add(const Duration(days: 146)),
        );
      }

      await _client
          .from('reproducoes')
          .update(atualizacao)
          .eq('id', reproducaoId)
          .eq('fazenda_id', fazendaId);
    }

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

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(
        'reproducao_nascimentos_${fazendaId}_$reproducaoId',
      );
      if (cache is! List) return [];
      return cache
          .whereType<Map>()
          .map(
            (item) =>
                ReproducaoNascimento.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
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

    final lista = resultado
        .map(
          (item) =>
              ReproducaoNascimento.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    await _offlineStore.salvarCache(
      'reproducao_nascimentos_${fazendaId}_$reproducaoId',
      lista.map((item) => item.toMap()).toList(),
    );
    return lista;
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

    if (!_connectivity.isOnline) {
      final reproducao = await getReproducaoPorId(reproducaoId);
      final animais = await AnimalService().getAnimaisAtivos();
      if (reproducao == null ||
          !animais.any((item) => item['id']?.toString() == animalId)) {
        throw Exception(
          'A reprodução e o cordeiro precisam estar salvos no aparelho.',
        );
      }
      final dados = {
        'id': const Uuid().v4(),
        'reproducao_id': reproducaoId,
        'animal_id': animalId,
        'sexo': sexo,
        'data_nascimento': _dateOnly(dataNascimento),
        'observacoes': _valorOuNull(observacoes),
        'criado_em': DateTime.now().toUtc().toIso8601String(),
      };
      await OfflineSyncService.instance.enfileirar(
        tipo: 'reproducao.nascimento',
        dados: {...dados, 'fazenda_id': fazendaId},
      );
      final key = 'reproducao_nascimentos_${fazendaId}_$reproducaoId';
      final cache = await _offlineStore.lerCache(key);
      final lista = cache is List
          ? cache
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      lista.add(dados);
      await _offlineStore.salvarCache(key, lista);
      return ReproducaoNascimento.fromMap(dados);
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

  Future<ReproducaoNascimento> registrarNascimentoNovoAnimal({
    required String reproducaoId,
    required String sexo,
    required DateTime dataNascimento,
    String? nome,
    String? observacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    if (!_connectivity.isOnline) {
      final reproducao = await getReproducaoPorId(reproducaoId);
      if (reproducao == null)
        throw Exception('Reprodução não encontrada no aparelho.');
      final animais = await AnimalService().getAnimaisAtivos();
      Map<String, dynamic>? mae;
      for (final item in animais) {
        if (item['id']?.toString() == reproducao.maeId) {
          mae = item;
          break;
        }
      }
      if (mae == null)
        throw Exception('A ovelha mãe precisa estar salva no aparelho.');
      final racaDados = mae['racas'];
      final racaNome = racaDados is Map
          ? (racaDados['nome']?.toString() ?? '')
          : (mae['raca']?.toString() ?? '');
      final animalService = AnimalService();
      final animalCriado = await animalService.criarAnimal(
        brinco: await animalService.getMenorBrincoDisponivel(),
        rebanhoId: mae['rebanho_id'].toString(),
        nome: nome,
        sexo: sexo,
        raca: racaNome,
        dataNascimento: dataNascimento,
        status: 'ativo',
        dataEntrada: dataNascimento,
        observacoes: observacoes,
        maeId: reproducao.maeId,
        paiId: reproducao.paiId,
        origem: 'nascido',
      );
      final nascimento = await registrarNascimento(
        reproducaoId: reproducaoId,
        animalId: animalCriado['id'].toString(),
        sexo: sexo,
        dataNascimento: dataNascimento,
        observacoes: observacoes,
      );
      await atualizarReproducao(
        reproducaoId: reproducaoId,
        maeId: reproducao.maeId,
        paiId: reproducao.paiId,
        dataCobertura: reproducao.dataCobertura,
        dataPrevisaoParto: reproducao.dataPrevisaoParto,
        dataParto: dataNascimento,
        status: 'parto_realizado',
        observacoes: reproducao.observacoes,
      );
      return nascimento;
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

    final mae = await _client
        .from('animais')
        .select('id, rebanho_id, raca_id, racas(nome)')
        .eq('id', reproducao['mae_id'])
        .eq('fazenda_id', fazendaId)
        .maybeSingle();

    if (mae == null) {
      throw Exception('A ovelha mãe não foi encontrada.');
    }

    final rebanhoId = mae['rebanho_id']?.toString();

    if (rebanhoId == null || rebanhoId.isEmpty) {
      throw Exception('A ovelha mãe não possui um rebanho válido.');
    }

    final racaDados = mae['racas'];
    final racaNome = racaDados is Map
        ? (racaDados['nome']?.toString() ?? '')
        : '';

    final animalService = AnimalService();
    final brinco = await animalService.getMenorBrincoDisponivel();

    Map<String, dynamic>? animalCriado;

    try {
      animalCriado = await animalService.criarAnimal(
        brinco: brinco,
        rebanhoId: rebanhoId,
        nome: nome,
        sexo: sexo,
        raca: racaNome,
        dataNascimento: dataNascimento,
        status: 'ativo',
        dataEntrada: dataNascimento,
        observacoes: observacoes,
        maeId: reproducao['mae_id']?.toString(),
        paiId: reproducao['pai_id']?.toString(),
        origem: 'nascido',
      );

      final nascimento = await registrarNascimento(
        reproducaoId: reproducaoId,
        animalId: animalCriado['id'].toString(),
        sexo: sexo,
        dataNascimento: dataNascimento,
        observacoes: observacoes,
      );

      await _client
          .from('reproducoes')
          .update({
            'data_parto': _dateOnly(dataNascimento),
            'status': 'parto_realizado',
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', reproducaoId)
          .eq('fazenda_id', fazendaId);

      return nascimento;
    } catch (e) {
      if (animalCriado != null) {
        try {
          await _client
              .from('animais')
              .delete()
              .eq('id', animalCriado['id'].toString())
              .eq('fazenda_id', fazendaId);
        } catch (_) {}
      }

      rethrow;
    }
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
