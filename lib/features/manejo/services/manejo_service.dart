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

  String _cacheManejos(String fazendaId) => 'manejos_$fazendaId';
  String _cacheManejosAnimal(String fazendaId, String animalId) =>
      'manejos_${fazendaId}_animal_$animalId';

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
      throw Exception(
        'Sem internet e a fazenda ainda não foi salva neste aparelho.',
      );
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
    final chaveCache = 'manejo_vacinas_$fazendaId';
    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(chaveCache);
      if (cache is List)
        return cache
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      return [];
    }

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

    final resultado = await _client
        .from('vacinas')
        .select(
          'id, nome, fabricante, ativo, dose, dose_unidade, peso_referencia_kg, via_aplicacao, carencia_dias, observacoes',
        )
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .order('nome');

    final lista = List<Map<String, dynamic>>.from(resultado);
    await _offlineStore.salvarCache(chaveCache, lista);
    return lista;
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

    final resultado = await _client
        .from('vacinas')
        .insert({
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
        })
        .select('*')
        .single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getVermifugos() async {
    final fazendaId = await _getMinhaFazendaId();
    final chaveCache = 'manejo_vermifugos_$fazendaId';
    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(chaveCache);
      if (cache is List)
        return cache
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      return [];
    }
    var resultado = await _client
        .from('vermifugos')
        .select('*')
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .order('nome');
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

    final lista = List<Map<String, dynamic>>.from(resultado);
    await _offlineStore.salvarCache(chaveCache, lista);
    return lista;
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

    final resultado = await _client
        .from('vermifugos')
        .insert({
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
        })
        .select('*')
        .single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<List<Map<String, dynamic>>> getMedicamentos() async {
    final fazendaId = await _getMinhaFazendaId();
    final chaveCache = 'manejo_medicamentos_$fazendaId';
    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(chaveCache);
      if (cache is List)
        return cache
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      return [];
    }
    final resultado = await _client
        .from('medicamentos')
        .select('*')
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .order('nome');
    final lista = List<Map<String, dynamic>>.from(resultado);
    await _offlineStore.salvarCache(chaveCache, lista);
    return lista;
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

    final resultado = await _client
        .from('medicamentos')
        .insert({
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
        })
        .select('*')
        .single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<double?> getUltimoPeso(String animalId) async {
    final pesos = await getUltimosPesos([animalId]);
    return pesos[animalId];
  }

  Future<Map<String, double>> getUltimosPesos(List<String> animalIds) async {
    if (animalIds.isEmpty) return {};

    final fazendaId = await _getMinhaFazendaId();
    final pesos = <String, double>{};
    final registros = <Map<String, dynamic>>[];
    try {
      if (_connectivity.isOnline) {
        final resultado = await _client
            .from('manejos')
            .select('animal_id, peso_kg, data, created_at')
            .eq('fazenda_id', fazendaId)
            .inFilter('animal_id', animalIds)
            .not('peso_kg', 'is', null)
            .order('data', ascending: false)
            .order('created_at', ascending: false);
        registros.addAll(List<Map<String, dynamic>>.from(resultado));
      }
    } catch (_) {
      // Usa os registros que já estão salvos localmente.
    }
    final cache = await _offlineStore.lerCache(_cacheManejos(fazendaId));
    if (cache is List) {
      registros.addAll(
        cache.whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
      );
    }
    final pendentes = await OfflineSyncService.instance.pendentes();
    final excluidos = pendentes
        .where((op) => op.tipo == 'manejo.excluir')
        .map((op) => op.dados['id']?.toString())
        .whereType<String>()
        .toSet();
    for (final op in pendentes) {
      final itens = switch (op.tipo) {
        'manejo.criar' => [op.dados],
        'manejo.criar_lote' => (op.dados['itens'] as List? ?? const []),
        _ => const <dynamic>[],
      };
      registros.addAll(
        itens
            .whereType<Map>()
            .where((item) => !excluidos.contains(item['id']?.toString()))
            .map((item) => Map<String, dynamic>.from(item)),
      );
    }

    registros.sort((a, b) {
      final data = (b['data']?.toString() ?? '').compareTo(
        a['data']?.toString() ?? '',
      );
      if (data != 0) return data;
      return (b['created_at']?.toString() ?? b['criado_em']?.toString() ?? '')
          .compareTo(
            a['created_at']?.toString() ?? a['criado_em']?.toString() ?? '',
          );
    });

    for (final item in registros) {
      if (!animalIds.contains(item['animal_id']?.toString())) continue;
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
      final cache = await _offlineStore.lerCache(_cacheManejos(fazendaId));
      if (cache is List)
        return cache
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      return [];
    }
    try {
      final resultado = await _client
          .from('manejos')
          .select('*, animais(brinco, nome)')
          .eq('fazenda_id', fazendaId)
          .order('data', ascending: false);
      final lista = List<Map<String, dynamic>>.from(resultado);
      await _offlineStore.salvarCache(_cacheManejos(fazendaId), lista);
      return lista;
    } catch (_) {
      final cache = await _offlineStore.lerCache(_cacheManejos(fazendaId));
      if (cache is List)
        return cache
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getManejosPorAnimal(
    String animalId,
  ) async {
    final fazendaId = await _getMinhaFazendaId();
    final cacheKey = _cacheManejosAnimal(fazendaId, animalId);
    List<Map<String, dynamic>> registros = [];

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(cacheKey);
      if (cache is List) {
        registros = cache
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } else {
        final todos = await getManejos();
        registros = todos
            .where((item) => item['animal_id']?.toString() == animalId)
            .toList();
      }
    } else {
      try {
        const tamanhoPagina = 500;
        var inicio = 0;
        while (true) {
          final pagina = await _client
              .from('manejos')
              .select('*')
              .eq('fazenda_id', fazendaId)
              .eq('animal_id', animalId)
              .order('data', ascending: false)
              .order('created_at', ascending: false)
              .range(inicio, inicio + tamanhoPagina - 1);
          final itens = List<Map<String, dynamic>>.from(pagina);
          registros.addAll(itens);
          if (itens.length < tamanhoPagina) break;
          inicio += tamanhoPagina;
        }
      } catch (_) {
        final cache = await _offlineStore.lerCache(cacheKey);
        if (cache is List) {
          registros = cache
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } else {
          rethrow;
        }
      }
    }

    final porId = <String, Map<String, dynamic>>{
      for (final item in registros)
        if (item['id'] != null) item['id'].toString(): item,
    };
    for (final operacao in await OfflineSyncService.instance.pendentes()) {
      final itens = switch (operacao.tipo) {
        'manejo.criar' => [operacao.dados],
        'manejo.criar_lote' => (operacao.dados['itens'] as List? ?? const []),
        _ => const <dynamic>[],
      };
      for (final item in itens) {
        if (item is! Map || item['animal_id']?.toString() != animalId) {
          continue;
        }
        final dados = Map<String, dynamic>.from(item);
        final id = dados['id']?.toString();
        if (id != null) porId[id] = dados;
      }
    }

    registros = porId.values.toList()
      ..sort(
        (a, b) => (b['data']?.toString() ?? '').compareTo(
          a['data']?.toString() ?? '',
        ),
      );
    await _offlineStore.salvarCache(cacheKey, registros);
    return registros;
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
    String? enfermidade,
    String? farmaciaProdutoId,
    double? farmaciaQuantidade,
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
      pesoKg: pesoKg,
      dose: dose,
      pesoReferenciaKg: pesoReferenciaKg,
      vermifugoId: vermifugoId,
      vermifugoNome: vermifugoNome,
      medicamentoId: medicamentoId,
      medicamentoNome: medicamentoNome,
    );

    final quantidadeFarmacia = farmaciaQuantidade ?? dose;
    if (farmaciaProdutoId != null &&
        (quantidadeFarmacia == null || quantidadeFarmacia <= 0)) {
      throw Exception('Informe a quantidade consumida da farmácia.');
    }

    if (_connectivity.isOnline) {
      await _validarAnimal(animalId, fazendaId);
    }

    final dados = _dadosManejo(
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
      pesoKg: pesoKg,
      dose: dose,
      doseUnidade: doseUnidade,
      pesoReferenciaKg: pesoReferenciaKg,
      viaAplicacao: viaAplicacao,
      validade: validade,
      carenciaDias: carenciaDias,
      vermifugoId: vermifugoId,
      vermifugoNome: vermifugoNome,
      vermifugoPrincipioAtivo: vermifugoPrincipioAtivo,
      medicamentoId: medicamentoId,
      medicamentoNome: medicamentoNome,
      medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
      enfermidade: enfermidade,
      farmaciaProdutoId: farmaciaProdutoId,
      farmaciaQuantidade: quantidadeFarmacia,
    );

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'manejo.criar',
        dados: dados,
      );
      await _atualizarCacheManejo(dados);
      return dados;
    }

    final resultado = farmaciaProdutoId != null
        ? await _client.rpc(
            'registrar_manejo_com_estoque',
            params: {
              'p_dados': dados,
              'p_quantidade': quantidadeFarmacia,
            },
          )
        : await _client
            .from('manejos')
            .insert(dados)
            .select('*, animais(brinco, nome)')
            .single();

    return Map<String, dynamic>.from(resultado as Map);
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
    String? enfermidade,
    String? farmaciaProdutoId,
    double? farmaciaQuantidade,
  }) async {
    final fazendaId = await _getMinhaFazendaId();
    if (animalIds.isEmpty) throw Exception('Selecione pelo menos um animal.');

    if (tipo == TipoManejo.famacha) {
      for (final id in animalIds) {
        final escore = famachaPorAnimal[id];
        if (escore == null || escore < 1 || escore > 5) {
          throw Exception(
            'Informe o FAMACHA de todos os animais selecionados.',
          );
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
      validarPeso: false,
    );

    final quantidadeFarmacia = farmaciaQuantidade ?? dose;
    if (farmaciaProdutoId != null &&
        (quantidadeFarmacia == null || quantidadeFarmacia <= 0)) {
      throw Exception('Informe a quantidade consumida da farmácia.');
    }

    if (_connectivity.isOnline) {
      final animais = await _client
          .from('animais')
          .select('id')
          .eq('fazenda_id', fazendaId)
          .eq('status', 'ativo')
          .inFilter('id', animalIds);
      final idsValidos = List<Map<String, dynamic>>.from(animais)
          .map((a) => a['id'].toString())
          .toSet();

      if (idsValidos.length != animalIds.length ||
          animalIds.any((id) => !idsValidos.contains(id))) {
        throw Exception(
          'Um ou mais animais não estão ativos ou não pertencem à fazenda.',
        );
      }
    }

    final dados = animalIds
        .map(
          (animalId) => _dadosManejo(
            fazendaId: fazendaId,
            animalId: animalId,
            tipo: tipo,
            data: data,
            famachaEscore: tipo == TipoManejo.famacha
                ? famachaPorAnimal[animalId]
                : null,
            observacoes: observacoes,
            vacinaId: vacinaId,
            vacinaNome: vacinaNome,
            vacinaFabricante: vacinaFabricante,
            vacinaLote: vacinaLote,
            outroNome: outroNome,
            pesoKg: pesoPorAnimal[animalId],
            dose: dosePorAnimal[animalId] ?? dose,
            doseUnidade: doseUnidade,
            pesoReferenciaKg: pesoReferenciaKg,
            viaAplicacao: viaAplicacao,
            validade: validade,
            carenciaDias: carenciaDias,
            vermifugoId: vermifugoId,
            vermifugoNome: vermifugoNome,
            vermifugoPrincipioAtivo: vermifugoPrincipioAtivo,
            medicamentoId: medicamentoId,
            medicamentoNome: medicamentoNome,
            medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
            enfermidade: enfermidade,
            farmaciaProdutoId: farmaciaProdutoId,
            farmaciaQuantidade: dosePorAnimal[animalId] ?? quantidadeFarmacia,
          ),
        )
        .toList();

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'manejo.criar_lote',
        dados: {'itens': dados},
      );
      for (final item in dados) {
        await _atualizarCacheManejo(item);
      }
      return dados;
    }

    final resultado = farmaciaProdutoId != null
        ? await _client.rpc(
            'registrar_manejos_com_estoque',
            params: {'p_itens': dados},
          )
        : await _client
            .from('manejos')
            .insert(dados)
            .select('*, animais(brinco, nome)');
    return List<Map<String, dynamic>>.from(resultado as List);
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
    String? enfermidade,
    String? farmaciaProdutoId,
    double? farmaciaQuantidade,
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
      pesoKg: pesoKg,
      dose: dose,
      pesoReferenciaKg: pesoReferenciaKg,
      vermifugoId: vermifugoId,
      vermifugoNome: vermifugoNome,
      medicamentoId: medicamentoId,
      medicamentoNome: medicamentoNome,
    );
    if (_connectivity.isOnline) {
      await _validarAnimal(animalId, fazendaId);
    }

    final dados =
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
            pesoKg: pesoKg,
            dose: dose,
            doseUnidade: doseUnidade,
            pesoReferenciaKg: pesoReferenciaKg,
            viaAplicacao: viaAplicacao,
            validade: validade,
            carenciaDias: carenciaDias,
            vermifugoId: vermifugoId,
            vermifugoNome: vermifugoNome,
            vermifugoPrincipioAtivo: vermifugoPrincipioAtivo,
            medicamentoId: medicamentoId,
            medicamentoNome: medicamentoNome,
            medicamentoPrincipioAtivo: medicamentoPrincipioAtivo,
            enfermidade: enfermidade,
          )
          ..remove('id')
          ..remove('fazenda_id');

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'manejo.atualizar',
        dados: {'id': id, 'fazenda_id': fazendaId, ...dados},
      );
      await _atualizarCacheManejo({
        'id': id,
        'fazenda_id': fazendaId,
        ...dados,
      });
      return;
    }

    await _client.rpc(
      'atualizar_manejo_com_estoque',
      params: {
        'p_id': id,
        'p_fazenda_id': fazendaId,
        'p_dados': {'id': id, 'fazenda_id': fazendaId, ...dados},
      },
    );
  }

  Future<void> excluirManejo(String id) async {
    final fazendaId = await _getMinhaFazendaId();
    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'manejo.excluir',
        dados: {'id': id, 'fazenda_id': fazendaId},
      );
      final cache = await _offlineStore.lerCache(_cacheManejos(fazendaId));
      if (cache is List) {
        final anteriores = cache
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['id']?.toString() == id)
            .toList();
        final lista = cache
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['id']?.toString() != id)
            .toList();
        await _offlineStore.salvarCache(_cacheManejos(fazendaId), lista);
        if (anteriores.isNotEmpty) {
          final animalId = anteriores.first['animal_id']?.toString();
          if (animalId != null) {
            final chave = _cacheManejosAnimal(fazendaId, animalId);
            final animalCache = await _offlineStore.lerCache(chave);
            if (animalCache is List) {
              await _offlineStore.salvarCache(
                chave,
                animalCache
                    .whereType<Map>()
                    .where((item) => item['id']?.toString() != id)
                    .toList(),
              );
            }
          }
        }
      }
      return;
    }
    await _client.rpc(
      'excluir_manejo_com_estoque',
      params: {'p_id': id, 'p_fazenda_id': fazendaId},
    );
  }

  Future<void> _atualizarCacheManejo(Map<String, dynamic> registro) async {
    final id = registro['id']?.toString();
    final animalId = registro['animal_id']?.toString();
    if (id == null || animalId == null) return;
    final atualizado = Map<String, dynamic>.from(registro);
    final usuarioId = _client.auth.currentUser?.id;
    if (usuarioId != null) {
      final animais = await _offlineStore.lerCache(
        'animais_${usuarioId}_todos_todos',
      );
      if (animais is List) {
        final correspondentes = animais
            .whereType<Map>()
            .where((item) => item['id']?.toString() == animalId)
            .toList();
        if (correspondentes.isNotEmpty) {
          atualizado['animais'] = {
            'brinco': correspondentes.first['brinco'],
            'nome': correspondentes.first['nome'],
          };
        }
      }
    }

    final fazendaId = registro['fazenda_id']?.toString();
    if (fazendaId == null) return;
    final cacheKey = _cacheManejos(fazendaId);
    final cache = await _offlineStore.lerCache(cacheKey);
    final lista = cache is List
        ? cache
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    lista.removeWhere((item) => item['id']?.toString() == id);
    lista.add(atualizado);
    lista.sort(
      (a, b) =>
          (b['data']?.toString() ?? '').compareTo(a['data']?.toString() ?? ''),
    );
    await _offlineStore.salvarCache(cacheKey, lista);

    final chaveAnimal = _cacheManejosAnimal(fazendaId, animalId);
    final cacheAnimal = await _offlineStore.lerCache(chaveAnimal);
    final listaAnimal = cacheAnimal is List
        ? cacheAnimal
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    listaAnimal.removeWhere((item) => item['id']?.toString() == id);
    listaAnimal.add(atualizado);
    listaAnimal.sort(
      (a, b) =>
          (b['data']?.toString() ?? '').compareTo(a['data']?.toString() ?? ''),
    );
    await _offlineStore.salvarCache(chaveAnimal, listaAnimal);
  }

  Future<void> _validarAnimal(String animalId, String fazendaId) async {
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
    bool validarPeso = true,
  }) {
    if (validarPeso &&
        tipo == TipoManejo.pesagem &&
        (pesoKg == null || pesoKg <= 0)) {
      throw Exception('Informe um peso válido em kg.');
    }
    if (dose != null && dose < 0)
      throw Exception('A dose não pode ser negativa.');
    if (dose != null && (pesoReferenciaKg == null || pesoReferenciaKg <= 0)) {
      throw Exception('Informe o peso de referência da dose.');
    }
    if (validarFamacha &&
        tipo == TipoManejo.famacha &&
        (famachaEscore == null || famachaEscore < 1 || famachaEscore > 5)) {
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
    if (tipo == TipoManejo.vermifugacao &&
        (vermifugoId == null &&
            (vermifugoNome == null || vermifugoNome.trim().isEmpty))) {
      throw Exception('Informe qual vermífugo foi aplicado.');
    }
    if (tipo == TipoManejo.tratamento &&
        (medicamentoId == null &&
            (medicamentoNome == null || medicamentoNome.trim().isEmpty))) {
      throw Exception('Informe qual medicamento foi utilizado.');
    }
    if (tipo == TipoManejo.outro &&
        (outroNome == null || outroNome.trim().isEmpty)) {
      throw Exception('Informe o nome do outro manejo.');
    }
    if (tipo != TipoManejo.outro &&
        outroNome != null &&
        outroNome.trim().isNotEmpty) {
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
    String? enfermidade,
    String? farmaciaProdutoId,
    double? farmaciaQuantidade,
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
      'vacina_fabricante': tipo == TipoManejo.vacinacao
          ? _text(vacinaFabricante)
          : null,
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
      'vermifugo_nome': tipo == TipoManejo.vermifugacao
          ? _text(vermifugoNome)
          : null,
      'vermifugo_principio_ativo': tipo == TipoManejo.vermifugacao
          ? _text(vermifugoPrincipioAtivo)
          : null,
      'medicamento_id': tipo == TipoManejo.tratamento ? medicamentoId : null,
      'medicamento_nome': tipo == TipoManejo.tratamento
          ? _text(medicamentoNome)
          : null,
      'medicamento_principio_ativo': tipo == TipoManejo.tratamento
          ? _text(medicamentoPrincipioAtivo)
          : null,
      'enfermidade': tipo == TipoManejo.tratamento ? _text(enfermidade) : null,
      'farmacia_produto_id': tipo == TipoManejo.vacinacao ||
              tipo == TipoManejo.vermifugacao ||
              tipo == TipoManejo.tratamento
          ? farmaciaProdutoId
          : null,
      'farmacia_quantidade': tipo == TipoManejo.vacinacao ||
              tipo == TipoManejo.vermifugacao ||
              tipo == TipoManejo.tratamento
          ? farmaciaQuantidade
          : null,
    };
  }

  String? _text(String? value) {
    final texto = value?.trim();
    return texto == null || texto.isEmpty ? null : texto;
  }
}
