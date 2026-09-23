import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/manejo.dart';

class ManejoService {
  SupabaseClient get _client => SupabaseService.client;
  String? _fazendaIdCache;
  final OfflineStore _offlineStore = OfflineStore();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  Future<String> _getMinhaFazendaId() async {
    if (_fazendaIdCache != null) return _fazendaIdCache!;

    final usuario = _client.auth.currentUser;
    if (usuario == null) throw Exception('Usuário não autenticado.');

    const chaveCache = 'manejo_fazenda_id';

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(chaveCache);
      final id = cache?.toString();
      if (id != null && id.isNotEmpty) {
        _fazendaIdCache = id;
        return id;
      }
      throw Exception('Sem internet e a fazenda ainda não foi salva neste aparelho.');
    }

    try {
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

      _fazendaIdCache = id;
      await _offlineStore.salvarCache(chaveCache, id);
      return id;
    } catch (_) {
      final cache = await _offlineStore.lerCache(chaveCache);
      final id = cache?.toString();
      if (id != null && id.isNotEmpty) {
        _fazendaIdCache = id;
        return id;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getVacinas() async {
    final fazendaId = await _getMinhaFazendaId();

    const padroes = [
      'Vacina contra clostridioses',
      'Vacina antirrábica',
      'Vacina contra ectima contagioso',
    ];

    final existentes = await _client
        .from('vacinas')
        .select('nome')
        .eq('fazenda_id', fazendaId)
        .inFilter('nome', padroes);

    final nomesExistentes = List<Map<String, dynamic>>.from(existentes)
        .map((item) => item['nome']?.toString())
        .whereType<String>()
        .toSet();

    final faltantes = padroes
        .where((nome) => !nomesExistentes.contains(nome))
        .map(
          (nome) => {
            'id': const Uuid().v4(),
            'fazenda_id': fazendaId,
            'nome': nome,
          },
        )
        .toList();

    if (faltantes.isNotEmpty) {
      await _client.from('vacinas').insert(faltantes);
    }

    final resultado = await _client.from('vacinas')
        .select('id, nome, fabricante, ativo, dose, dose_unidade, peso_referencia_kg, via_aplicacao, carencia_dias, observacoes')
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .order('nome');

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarVacina({
    required String nome,
    String? fabricante,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    int? carenciaDias,
    String? observacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (nome.trim().isEmpty) throw Exception('Informe o nome da vacina.');

    final resultado = await _client.from('vacinas').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'nome': nome.trim(),
      'fabricante': _text(fabricante),
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'carencia_dias': carenciaDias,
      'observacoes': _text(observacoes),
    }).select('*').single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getVermifugos() async {
    final fazendaId = await _getMinhaFazendaId();
    var resultado = await _client.from('vermifugos').select('*')
        .eq('fazenda_id', fazendaId).eq('ativo', true).order('nome');
    if (resultado.isEmpty) {
      const padroes = ['Albendazol', 'Ivermectina', 'Levamisol', 'Moxidectina'];
      final novos = padroes
          .map(
            (nome) => {
              'id': const Uuid().v4(),
              'fazenda_id': fazendaId,
              'nome': nome,
              'principio_ativo': nome,
            },
          )
          .toList();

      await _client.from('vermifugos').insert(novos);
      resultado = await _client
          .from('vermifugos')
          .select('*')
          .eq('fazenda_id', fazendaId)
          .eq('ativo', true)
          .order('nome');
    }

    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarVermifugo({
    required String nome,
    String? principioAtivo,
    String? concentracao,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    int? carenciaDias,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (nome.trim().isEmpty) throw Exception('Informe o nome do vermífugo.');

    final resultado = await _client.from('vermifugos').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'nome': nome.trim(),
      'principio_ativo': _text(principioAtivo),
      'concentracao': _text(concentracao),
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'carencia_dias': carenciaDias,
    }).select('*').single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getMedicamentos() async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('medicamentos').select('*')
        .eq('fazenda_id', fazendaId).eq('ativo', true).order('nome');
    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> criarMedicamento({
    required String nome,
    String? principioAtivo,
    String? concentracao,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    int? carenciaDias,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (nome.trim().isEmpty) throw Exception('Informe o nome do medicamento.');

    final resultado = await _client.from('medicamentos').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'nome': nome.trim(),
      'principio_ativo': _text(principioAtivo),
      'concentracao': _text(concentracao),
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'carencia_dias': carenciaDias,
    }).select('*').single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<double?> getUltimoPeso(String animalId) async {
    final pesos = await getUltimosPesos([animalId]);
    return pesos[animalId];
  }

  Future<Map<String, double>> getUltimosPesos(List<String> animalIds) async {
    if (animalIds.isEmpty) return {};

    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client
        .from('manejos')
        .select('animal_id, peso_kg, data, created_at')
        .eq('fazenda_id', fazendaId)
        .inFilter('animal_id', animalIds)
        .not('peso_kg', 'is', null)
        .order('data', ascending: false)
        .order('created_at', ascending: false);

    final pesos = <String, double>{};

    for (final item in resultado) {
      final id = item['animal_id']?.toString();
      if (id == null || pesos.containsKey(id)) continue;

      final valor = item['peso_kg'];
      final peso = valor is num
          ? valor.toDouble()
          : double.tryParse(valor?.toString() ?? '');

      if (peso != null && peso > 0) {
        pesos[id] = peso;
      }
    }

    return pesos;
  }

  Future<List<Map<String, dynamic>>> getManejos() async {
    final fazendaId = await _getMinhaFazendaId();
    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('manejos');
      if (cache is List) return cache.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return [];
    }
    try {
      final resultado = await _client.from('manejos')
          .select('*, animais(brinco, nome)')
          .eq('fazenda_id', fazendaId)
          .order('data', ascending: false);
      final lista = List<Map<String, dynamic>>.from(resultado);
      await _offlineStore.salvarCache('manejos', lista);
      return lista;
    } catch (_) {
      final cache = await _offlineStore.lerCache('manejos');
      if (cache is List) return cache.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      rethrow;
    }
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
    double? pesoKg,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    DateTime? validade,
    int? carenciaDias,
    String? vermifugoId,
    String? vermifugoNome,
    String? vermifugoPrincipioAtivo,
    String? medicamentoId,
    String? medicamentoNome,
    String? medicamentoPrincipioAtivo,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    _validarDados(
      tipo: tipo, famachaEscore: famachaEscore, vacinaId: vacinaId,
      vacinaNome: vacinaNome, vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote, outroNome: outroNome, pesoKg: pesoKg,
      dose: dose, pesoReferenciaKg: pesoReferenciaKg,
      vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
      medicamentoId: medicamentoId, medicamentoNome: medicamentoNome,
    );

    if (_connectivity.isOnline) {
      await _validarAnimal(animalId, fazendaId);
    }

    final dados = _dadosManejo(
      fazendaId: fazendaId, animalId: animalId, tipo: tipo, data: data,
      famachaEscore: famachaEscore, observacoes: observacoes,
      vacinaId: vacinaId, vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante, vacinaLote: vacinaLote,
      outroNome: outroNome, pesoKg: pesoKg, dose: dose,
      doseUnidade: doseUnidade, pesoReferenciaKg: pesoReferenciaKg,
      viaAplicacao: viaAplicacao, validade: validade,
      carenciaDias: carenciaDias, vermifugoId: vermifugoId,
      vermifugoNome: vermifugoNome, vermifugoPrincipioAtivo: vermifugoPrincipioAtivo,
      medicamentoId: medicamentoId, medicamentoNome: medicamentoNome,
      medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
    );

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'manejo.criar', dados: dados,
      );
      return dados;
    }

    final resultado = await _client.from('manejos').insert(dados)
        .select('*, animais(brinco, nome)').single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> criarManejosEmLote({
    required List<String> animalIds,
    required DateTime data,
    required TipoManejo tipo,
    Map<String, int> famachaPorAnimal = const {},
    Map<String, double> pesoPorAnimal = const {},
    Map<String, double> dosePorAnimal = const {},
    String? observacoes,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    DateTime? validade,
    int? carenciaDias,
    String? vermifugoId,
    String? vermifugoNome,
    String? vermifugoPrincipioAtivo,
    String? medicamentoId,
    String? medicamentoNome,
    String? medicamentoPrincipioAtivo,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (animalIds.isEmpty) throw Exception('Selecione pelo menos um animal.');

    if (tipo == TipoManejo.famacha) {
      for (final id in animalIds) {
        final escore = famachaPorAnimal[id];
        if (escore == null || escore < 1 || escore > 5) {
          throw Exception('Informe o FAMACHA de todos os animais selecionados.');
        }
      }
    }

    if (tipo == TipoManejo.pesagem) {
      for (final id in animalIds) {
        final peso = pesoPorAnimal[id];
        if (peso == null || peso <= 0) {
          throw Exception('Informe o peso de todos os animais selecionados.');
        }
      }
    }

    _validarDados(
      tipo: tipo,
      vacinaId: vacinaId,
      vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote,
      outroNome: outroNome,
      dose: dose,
      pesoReferenciaKg: pesoReferenciaKg,
      vermifugoId: vermifugoId,
      vermifugoNome: vermifugoNome,
      medicamentoId: medicamentoId,
      medicamentoNome: medicamentoNome,
      validarFamacha: false,
    );

    final animais = await _client.from('animais').select('id')
        .eq('fazenda_id', fazendaId).eq('status', 'ativo').inFilter('id', animalIds);
    final idsValidos = List<Map<String, dynamic>>.from(animais)
        .map((a) => a['id'].toString()).toSet();

    if (idsValidos.length != animalIds.length ||
        animalIds.any((id) => !idsValidos.contains(id))) {
      throw Exception('Um ou mais animais não estão ativos ou não pertencem à fazenda.');
    }

    final dados = animalIds.map((animalId) => _dadosManejo(
      fazendaId: fazendaId, animalId: animalId, tipo: tipo, data: data,
      famachaEscore: tipo == TipoManejo.famacha ? famachaPorAnimal[animalId] : null,
      observacoes: observacoes, vacinaId: vacinaId, vacinaNome: vacinaNome,
      vacinaFabricante: vacinaFabricante, vacinaLote: vacinaLote,
      outroNome: outroNome, pesoKg: pesoPorAnimal[animalId],
      dose: dosePorAnimal[animalId] ?? dose, doseUnidade: doseUnidade, pesoReferenciaKg: pesoReferenciaKg,
      viaAplicacao: viaAplicacao, validade: validade, carenciaDias: carenciaDias,
      vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
      vermifugoPrincipioAtivo: vermifugoPrincipioAtivo, medicamentoId: medicamentoId,
      medicamentoNome: medicamentoNome, medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
    )).toList();

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'manejo.criar_lote',
        dados: {'itens': dados},
      );
      return dados;
    }

    final resultado = await _client.from('manejos').insert(dados)
        .select('*, animais(brinco, nome)');
    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getHistoricoFamacha(String animalId) async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('manejos')
        .select('*, animais(brinco, nome)').eq('fazenda_id', fazendaId)
        .eq('animal_id', animalId).eq('tipo', 'famacha')
        .order('data', ascending: false);
    return List<Map<String, dynamic>>.from(resultado);
  }

  Future<Map<String, dynamic>> getManejo(String id) async {
    final fazendaId = await _getMinhaFazendaId();
    final resultado = await _client.from('manejos')
        .select('*, animais(brinco, nome)').eq('id', id)
        .eq('fazenda_id', fazendaId).single();
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
    String? outroNome,
    double? pesoKg,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    DateTime? validade,
    int? carenciaDias,
    String? vermifugoId,
    String? vermifugoNome,
    String? vermifugoPrincipioAtivo,
    String? medicamentoId,
    String? medicamentoNome,
    String? medicamentoPrincipioAtivo,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    _validarDados(
      tipo: tipo, famachaEscore: famachaEscore, vacinaId: vacinaId,
      vacinaNome: vacinaNome, vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote, outroNome: outroNome, pesoKg: pesoKg,
      dose: dose, pesoReferenciaKg: pesoReferenciaKg,
      vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
      medicamentoId: medicamentoId, medicamentoNome: medicamentoNome,
    );
    if (_connectivity.isOnline) {
      await _validarAnimal(animalId, fazendaId);
    }

    final dados = _dadosManejo(
      fazendaId: fazendaId, animalId: animalId, tipo: tipo, data: data,
      famachaEscore: famachaEscore, observacoes: observacoes,
      vacinaId: vacinaId, vacinaNome: vacinaNome, vacinaFabricante: vacinaFabricante,
      vacinaLote: vacinaLote, outroNome: outroNome, pesoKg: pesoKg,
      dose: dose, doseUnidade: doseUnidade, pesoReferenciaKg: pesoReferenciaKg,
      viaAplicacao: viaAplicacao, validade: validade, carenciaDias: carenciaDias,
      vermifugoId: vermifugoId, vermifugoNome: vermifugoNome,
      vermifugoPrincipioAtivo: vermifugoPrincipioAtivo, medicamentoId: medicamentoId,
      medicamentoNome: medicamentoNome, medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
    )..remove('id')..remove('fazenda_id');

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'manejo.atualizar',
        dados: {'id': id, 'fazenda_id': fazendaId, ...dados},
      );
      return;
    }

    await _client.from('manejos').update(dados)
        .eq('id', id).eq('fazenda_id', fazendaId);
  }

  Future<void> excluirManejo(String id) async {
    final fazendaId = await _getMinhaFazendaId();
    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'manejo.excluir',
        dados: {'id': id, 'fazenda_id': fazendaId},
      );
      return;
    }
    await _client.from('manejos').delete().eq('id', id).eq('fazenda_id', fazendaId);
  }

  Future<void> _validarAnimal(String animalId, String fazendaId) async {
    final animal = await _client.from('animais').select('id')
        .eq('id', animalId).eq('fazenda_id', fazendaId).eq('status', 'ativo')
        .maybeSingle();
    if (animal == null) {
      throw Exception('O animal selecionado não está ativo ou não pertence à fazenda.');
    }
  }

  void _validarDados({
    required TipoManejo tipo,
    int? famachaEscore,
    String? vacinaId,
    String? vacinaNome,
    String? vacinaFabricante,
    String? vacinaLote,
    String? outroNome,
    double? pesoKg,
    double? dose,
    double? pesoReferenciaKg,
    String? vermifugoId,
    String? vermifugoNome,
    String? medicamentoId,
    String? medicamentoNome,
    bool validarFamacha = true,
  }) {
    if (tipo == TipoManejo.pesagem && (pesoKg == null || pesoKg <= 0)) {
      throw Exception('Informe um peso válido em kg.');
    }
    if (dose != null && dose < 0) throw Exception('A dose não pode ser negativa.');
    if (dose != null && (pesoReferenciaKg == null || pesoReferenciaKg <= 0)) {
      throw Exception('Informe o peso de referência da dose.');
    }
    if (validarFamacha &&
        tipo == TipoManejo.famacha &&
        (famachaEscore == null || famachaEscore < 1 || famachaEscore > 5)) {
      throw Exception('Informe uma classificação FAMACHA de 1 a 5.');
    }
    if (tipo != TipoManejo.famacha && famachaEscore != null) {
      throw Exception('A classificação FAMACHA só pode ser usada em uma avaliação FAMACHA.');
    }
    if (tipo == TipoManejo.vacinacao &&
        (vacinaId == null && (vacinaNome == null || vacinaNome.trim().isEmpty))) {
      throw Exception('Informe qual vacina foi aplicada.');
    }
    if (tipo == TipoManejo.vermifugacao &&
        (vermifugoId == null && (vermifugoNome == null || vermifugoNome.trim().isEmpty))) {
      throw Exception('Informe qual vermífugo foi aplicado.');
    }
    if (tipo == TipoManejo.tratamento &&
        (medicamentoId == null && (medicamentoNome == null || medicamentoNome.trim().isEmpty))) {
      throw Exception('Informe qual medicamento foi utilizado.');
    }
    if (tipo == TipoManejo.outro &&
        (outroNome == null || outroNome.trim().isEmpty)) {
      throw Exception('Informe o nome do outro manejo.');
    }
    if (tipo != TipoManejo.outro && outroNome != null && outroNome.trim().isNotEmpty) {
      throw Exception('O nome personalizado só pode ser usado em Outro.');
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
    double? pesoKg,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    DateTime? validade,
    int? carenciaDias,
    String? vermifugoId,
    String? vermifugoNome,
    String? vermifugoPrincipioAtivo,
    String? medicamentoId,
    String? medicamentoNome,
    String? medicamentoPrincipioAtivo,
  }) {
    return {
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'animal_id': animalId,
      'tipo': Manejo.tipoToString(tipo),
      'data': data.toIso8601String(),
      'famacha_escore': tipo == TipoManejo.famacha ? famachaEscore : null,
      'observacoes': _text(observacoes),
      'vacina_id': tipo == TipoManejo.vacinacao ? vacinaId : null,
      'vacina_nome': tipo == TipoManejo.vacinacao ? _text(vacinaNome) : null,
      'vacina_fabricante': tipo == TipoManejo.vacinacao ? _text(vacinaFabricante) : null,
      'vacina_lote': tipo == TipoManejo.vacinacao ? _text(vacinaLote) : null,
      'outro_nome': tipo == TipoManejo.outro ? _text(outroNome) : null,
      'peso_kg': pesoKg,
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'validade': validade?.toIso8601String(),
      'carencia_dias': carenciaDias,
      'vermifugo_id': tipo == TipoManejo.vermifugacao ? vermifugoId : null,
      'vermifugo_nome': tipo == TipoManejo.vermifugacao ? _text(vermifugoNome) : null,
      'vermifugo_principio_ativo': tipo == TipoManejo.vermifugacao ? _text(vermifugoPrincipioAtivo) : null,
      'medicamento_id': tipo == TipoManejo.tratamento ? medicamentoId : null,
      'medicamento_nome': tipo == TipoManejo.tratamento ? _text(medicamentoNome) : null,
      'medicamento_principio_ativo': tipo == TipoManejo.tratamento ? _text(medicamentoPrincipioAtivo) : null,
    };
  }

  String? _text(String? value) {
    final texto = value?.trim();
    return texto == null || texto.isEmpty ? null : texto;
  }
}
