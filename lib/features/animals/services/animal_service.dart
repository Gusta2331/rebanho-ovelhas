import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/services/supabase_service.dart';

class AnimalService {
  SupabaseClient get _client => SupabaseService.client;
  final OfflineStore _offlineStore = OfflineStore();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  String _cacheKey(String usuarioId, String tipo, String? rebanhoId) {
    final sufixo = rebanhoId ?? 'todos';
    return 'animais_' + usuarioId + '_' + tipo + '_' + sufixo;
  }

  String _farmCacheKey(String usuarioId) => 'fazenda_id_' + usuarioId;

  Future<String?> _getMinhaFazendaId() async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    if (!_connectivity.isOnline) {
      return await _offlineStore.lerCache(_farmCacheKey(usuario.id)) as String?;
    }

    try {
      final fazenda = await _client
          .from('fazendas')
          .select('id')
          .eq('proprietario_id', usuario.id)
          .eq('ativo', true)
          .maybeSingle();

      final id = fazenda?['id'] as String?;

      if (id != null) {
        await _offlineStore.salvarCache(_farmCacheKey(usuario.id), id);
      }

      return id;
    } catch (_) {
      return await _offlineStore.lerCache(_farmCacheKey(usuario.id)) as String?;
    }
  }

  Future<List<Map<String, dynamic>>> getAnimaisAtivos({
    String? rebanhoId,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    final usuario = _client.auth.currentUser!;
    final chaveCache = _cacheKey(usuario.id, 'ativos', rebanhoId);

    if (!_connectivity.isOnline) {
      return _lerAnimaisDoCache(chaveCache);
    }

    try {
      final lista = await _buscarAnimaisPaginados(
        fazendaId: fazendaId,
        rebanhoId: rebanhoId,
        somenteAtivos: true,
      );

      await _offlineStore.salvarCache(chaveCache, lista);
      return lista;
    } catch (_) {
      return _lerAnimaisDoCache(chaveCache);
    }
  }

  Future<List<Map<String, dynamic>>> getTodosAnimais({
    String? rebanhoId,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    final usuario = _client.auth.currentUser!;
    final chaveCache = _cacheKey(usuario.id, 'todos', rebanhoId);

    if (!_connectivity.isOnline) {
      return _lerAnimaisDoCache(chaveCache);
    }

    try {
      final lista = await _buscarAnimaisPaginados(
        fazendaId: fazendaId,
        rebanhoId: rebanhoId,
      );

      await _offlineStore.salvarCache(chaveCache, lista);
      return lista;
    } catch (_) {
      return _lerAnimaisDoCache(chaveCache);
    }
  }

  Future<List<Map<String, dynamic>>> _buscarAnimaisPaginados({
    required String fazendaId,
    String? rebanhoId,
    bool somenteAtivos = false,
  }) async {
    const tamanhoPagina = 500;
    final todos = <Map<String, dynamic>>[];
    var inicio = 0;

    while (true) {
      var consulta = _client
          .from('animais')
          .select('*, racas(nome)')
          .eq('fazenda_id', fazendaId);
      if (somenteAtivos) consulta = consulta.eq('status', 'ativo');
      if (rebanhoId != null) {
        consulta = consulta.eq('rebanho_id', rebanhoId);
      }

      final pagina = await consulta
          .order('brinco')
          .order('id')
          .range(inicio, inicio + tamanhoPagina - 1);
      final registros = List<Map<String, dynamic>>.from(pagina);
      todos.addAll(registros);

      if (registros.length < tamanhoPagina) break;
      inicio += tamanhoPagina;
    }

    return todos;
  }

  Future<List<Map<String, dynamic>>> getAnimaisPorIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }

    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      return [];
    }

    if (!_connectivity.isOnline) {
      final todos = await getTodosAnimais();
      return todos
          .where((animal) => ids.contains(animal['id']?.toString()))
          .toList();
    }

    try {
      final animais = await _client
          .from('animais')
          .select('*, racas(nome)')
          .eq('fazenda_id', fazendaId)
          .inFilter('id', ids);

      return List<Map<String, dynamic>>.from(animais);
    } catch (_) {
      final todos = await getTodosAnimais();
      return todos
          .where((animal) => ids.contains(animal['id']?.toString()))
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> _lerAnimaisDoCache(String chave) async {
    final valor = await _offlineStore.lerCache(chave);

    if (valor is! List) {
      return [];
    }

    return valor
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<int> getTotalAnimaisAtivos({String? rebanhoId}) async {
    final animais = await getAnimaisAtivos(rebanhoId: rebanhoId);

    return animais.length;
  }

  Future<int> getTotalFemeasAtivas({String? rebanhoId}) async {
    final animais = await getAnimaisAtivos(rebanhoId: rebanhoId);

    return animais.where((animal) => animal['sexo'] == 'femea').length;
  }

  Future<int> getTotalMachosAtivos({String? rebanhoId}) async {
    final animais = await getAnimaisAtivos(rebanhoId: rebanhoId);

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

    final existente = await _buscarRacaPorNome(nome, fazendaId);
    if (existente != null) return existente['id'] as String?;

    // A tela de raças historicamente permitia opções locais não cadastradas
    // no banco. Persista a opção aqui para que o FK raca_id nunca seja perdido.
    final criada = await _client
        .from('racas')
        .insert({
          'id': const Uuid().v4(),
          'fazenda_id': fazendaId,
          'nome': nome.trim(),
          'ativo': true,
        })
        .select('id')
        .single();
    return criada['id'] as String?;
  }

  Future<bool> _rebanhoPertenceAFazenda({
    required String rebanhoId,
    required String fazendaId,
  }) async {
    final rebanho = await _client
        .from('rebanhos')
        .select('id')
        .eq('id', rebanhoId)
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .maybeSingle();

    return rebanho != null;
  }

  Future<Map<String, dynamic>> criarAnimal({
    required int brinco,
    required String rebanhoId,
    String? nome,
    required String sexo,
    required String raca,
    DateTime? dataNascimento,
    required String status,
    DateTime? dataEntrada,
    String? observacoes,
    String? fotoUrl,
    String? fotoPath,
    String? maeId,
    String? paiId,
    String origem = 'nascido',
    DateTime? dataAquisicao,
    double? valorAquisicao,
    String? vendedor,
    String? denticao,
    DateTime? denticaoData,
    String? denticaoObservacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    if (origem != 'nascido' && origem != 'comprado') {
      throw Exception('Origem do animal inválida.');
    }

    if (origem == 'comprado') {
      if (dataAquisicao == null) {
        throw Exception('Informe a data da compra.');
      }

      if (valorAquisicao == null || valorAquisicao <= 0) {
        throw Exception('Informe um valor de compra maior que zero.');
      }
    }

    final rebanhoValido = await _rebanhoPertenceAFazenda(
      rebanhoId: rebanhoId,
      fazendaId: fazendaId,
    );

    if (!rebanhoValido) {
      throw Exception(
        'O rebanho selecionado não pertence à fazenda atual ou está inativo.',
      );
    }

    final disponivel = await brincoDisponivel(brinco: brinco);

    if (!disponivel) {
      throw Exception('O brinco $brinco já foi utilizado por outro animal.');
    }

    final racaId = await _buscarRacaId(nome: raca, fazendaId: fazendaId);

    final animalId = const Uuid().v4();

    final fotoUrlFinal = await _resolverFotoParaSalvar(
      fotoUrl: fotoUrl,
      fotoPath: fotoPath,
      fazendaId: fazendaId,
      animalId: animalId,
    );

    final dados = <String, dynamic>{
      'id': animalId,
      'fazenda_id': fazendaId,
      'rebanho_id': rebanhoId,
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
      'foto_url': fotoUrlFinal,
      'mae_id': maeId,
      'pai_id': paiId,
      'origem': origem,
      'data_aquisicao': origem == 'comprado'
          ? dataAquisicao!.toIso8601String().split('T').first
          : null,
      'valor_aquisicao': origem == 'comprado' ? valorAquisicao : null,
      'vendedor': origem == 'comprado' && vendedor?.trim().isNotEmpty == true
          ? vendedor!.trim()
          : null,
      'denticao': denticao,
      'denticao_data': denticaoData?.toIso8601String().split('T').first,
      'denticao_observacoes': denticaoObservacoes?.trim().isEmpty == true
          ? null
          : denticaoObservacoes?.trim(),
    };

    if (origem == 'comprado') {
      await _client.rpc(
        'criar_animal_com_compra',
        params: {
          'p_animal_id': animalId,
          'p_rebanho_id': rebanhoId,
          'p_brinco': brinco,
          'p_nome': nome?.trim(),
          'p_sexo': sexo,
          'p_raca_id': racaId,
          'p_data_nascimento': dataNascimento?.toIso8601String(),
          'p_status': status,
          'p_data_entrada': dataEntrada?.toIso8601String(),
          'p_observacoes': observacoes?.trim(),
          'p_foto_url': fotoUrlFinal,
          'p_mae_id': maeId,
          'p_pai_id': paiId,
          'p_data_aquisicao': dataAquisicao!.toIso8601String().split('T').first,
          'p_valor_aquisicao': valorAquisicao,
          'p_vendedor': vendedor?.trim(),
        },
      );
      await _client.from('animais').update({
        'denticao': denticao,
        'denticao_data': denticaoData?.toIso8601String().split('T').first,
        'denticao_observacoes': denticaoObservacoes?.trim().isEmpty == true
            ? null
            : denticaoObservacoes?.trim(),
      }).eq('id', animalId).eq('fazenda_id', fazendaId);
    } else {
      await _client.from('animais').insert(dados);
    }

    final resultado = await _client
        .from('animais')
        .select('*, racas(nome)')
        .eq('id', animalId)
        .single();

    return Map<String, dynamic>.from(resultado);
  }

  Future<Map<String, dynamic>> atualizarAnimal({
    required String id,
    required int brinco,
    required String rebanhoId,
    String? nome,
    required String sexo,
    required String raca,
    DateTime? dataNascimento,
    required String status,
    DateTime? dataEntrada,
    DateTime? dataSaida,
    String? observacoes,
    String? fotoUrl,
    String? fotoPath,
    String? maeId,
    String? paiId,
    String origem = 'nascido',
    DateTime? dataAquisicao,
    double? valorAquisicao,
    String? vendedor,
    String? denticao,
    DateTime? denticaoData,
    String? denticaoObservacoes,
  }) async {
    final fazendaId = await _getMinhaFazendaId();

    if (fazendaId == null) {
      throw Exception('Nenhuma fazenda ativa foi encontrada.');
    }

    final rebanhoValido = await _rebanhoPertenceAFazenda(
      rebanhoId: rebanhoId,
      fazendaId: fazendaId,
    );

    if (!rebanhoValido) {
      throw Exception(
        'O rebanho selecionado não pertence à fazenda atual ou está inativo.',
      );
    }

    final disponivel = await brincoDisponivel(
      brinco: brinco,
      animalIdAtual: id,
    );

    if (!disponivel) {
      throw Exception('O brinco $brinco já foi utilizado por outro animal.');
    }

    final racaId = await _buscarRacaId(nome: raca, fazendaId: fazendaId);

    final fotoUrlFinal = await _resolverFotoParaSalvar(
      fotoUrl: fotoUrl,
      fotoPath: fotoPath,
      fazendaId: fazendaId,
      animalId: id,
    );

    if (origem != 'nascido' && origem != 'comprado') {
      throw Exception('Origem do animal inválida.');
    }
    if (origem == 'comprado' &&
        (dataAquisicao == null || valorAquisicao == null || valorAquisicao <= 0)) {
      throw Exception('Informe a data e um valor de compra maior que zero.');
    }

    final resultado = await _client.rpc(
      'atualizar_animal_com_origem',
      params: {
        'p_animal_id': id,
        'p_rebanho_id': rebanhoId,
        'p_brinco': brinco,
        'p_nome': nome?.trim(),
        'p_sexo': sexo,
        'p_raca_id': racaId,
        'p_data_nascimento': dataNascimento?.toIso8601String(),
        'p_status': status,
        'p_data_entrada': dataEntrada?.toIso8601String(),
        'p_data_saida': dataSaida?.toIso8601String(),
        'p_observacoes': observacoes?.trim(),
        'p_foto_url': fotoUrlFinal,
        'p_mae_id': maeId,
        'p_pai_id': paiId,
        'p_origem': origem,
        'p_data_aquisicao': origem == 'comprado'
            ? dataAquisicao!.toIso8601String().split('T').first
            : null,
        'p_valor_aquisicao': origem == 'comprado' ? valorAquisicao : null,
        'p_vendedor': origem == 'comprado' ? vendedor?.trim() : null,
        'p_denticao': denticao,
        'p_denticao_data': denticaoData?.toIso8601String().split('T').first,
        'p_denticao_observacoes': denticaoObservacoes?.trim(),
      },
    );

    final animal = await _client
        .from('animais')
        .select('*, racas(nome)')
        .eq('id', id)
        .eq('fazenda_id', fazendaId)
        .single();
    return Map<String, dynamic>.from(animal);
  }

  Future<void> excluirAnimal(String id) async {
    if (!_connectivity.isOnline) {
      throw Exception('Conecte-se à internet para excluir o animal com segurança.');
    }
    await _client.rpc('excluir_animal_e_historico', params: {'p_animal_id': id});
  }

  Future<String?> _resolverFotoParaSalvar({
    required String fazendaId,
    required String animalId,
    String? fotoUrl,
    String? fotoPath,
  }) async {
    final caminho = fotoPath?.trim();

    if (caminho != null && caminho.isNotEmpty) {
      if (caminho.startsWith('http://') || caminho.startsWith('https://')) {
        return caminho;
      }

      final arquivo = File(caminho);

      if (!await arquivo.exists()) {
        throw Exception(
          'A foto selecionada não está mais disponível no celular.',
        );
      }

      final extensao = _extensaoFoto(caminho);
      final caminhoStorage = '$fazendaId/$animalId.$extensao';

      await _client.storage
          .from('animal-fotos')
          .upload(
            caminhoStorage,
            arquivo,
            fileOptions: FileOptions(
              contentType: _contentTypeFoto(extensao),
              upsert: true,
            ),
          );

      return _client.storage.from('animal-fotos').getPublicUrl(caminhoStorage);
    }

    final url = fotoUrl?.trim();

    if (url == null || url.isEmpty) {
      return null;
    }

    return url;
  }

  String _extensaoFoto(String caminho) {
    final nome = caminho.split('/').last;
    final partes = nome.split('.');

    if (partes.length < 2) {
      return 'jpg';
    }

    final extensao = partes.last.toLowerCase();

    switch (extensao) {
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      case 'heic':
        return 'heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'jpg';
    }
  }

  String _contentTypeFoto(String extensao) {
    switch (extensao) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
