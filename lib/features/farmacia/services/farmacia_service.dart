import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/services/supabase_service.dart';

class FarmaciaService {
  SupabaseClient get _client => SupabaseService.client;
  final OfflineStore _offlineStore = OfflineStore();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  Future<String> _fazendaId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    const chaveCache = 'farmacia_fazenda_id';

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(chaveCache);
      final id = cache?.toString();
      if (id != null && id.isNotEmpty) return id;
      throw Exception(
        'Sem internet e a fazenda ainda não foi salva neste aparelho.',
      );
    }

    try {
      final farm = await _client
          .from('fazendas')
          .select('id')
          .eq('proprietario_id', user.id)
          .eq('ativo', true)
          .maybeSingle();
      final id = farm?['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Nenhuma fazenda ativa foi encontrada.');
      }
      await _offlineStore.salvarCache(chaveCache, id);
      return id;
    } catch (_) {
      final cache = await _offlineStore.lerCache(chaveCache);
      final id = cache?.toString();
      if (id != null && id.isNotEmpty) return id;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listarProdutos() async {
    final fazendaId = await _fazendaId();

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('farmacia_produtos');
      if (cache is List) {
        return cache
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    final result = await _client
        .from('farmacia_produtos')
        .select('*, farmacia_lotes(*)')
        .eq('fazenda_id', fazendaId)
        .eq('ativo', true)
        .order('nome');

    final lista = List<Map<String, dynamic>>.from(result);
    await _offlineStore.salvarCache('farmacia_produtos', lista);
    return lista;
  }

  Future<List<Map<String, dynamic>>> listarLotes(String produtoId) async {
    final fazendaId = await _fazendaId();

    if (!_connectivity.isOnline) {
      final produtos = await listarProdutos();
      final produto = produtos.firstWhere(
        (p) => p['id']?.toString() == produtoId,
        orElse: () => <String, dynamic>{},
      );
      final lotes = produto['farmacia_lotes'];
      if (lotes is List) {
        return lotes
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    final result = await _client
        .from('farmacia_lotes')
        .select('*')
        .eq('fazenda_id', fazendaId)
        .eq('produto_id', produtoId)
        .order('validade', ascending: true)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Map<String, dynamic>>> listarAlertas({
    bool apenasAbertos = true,
  }) async {
    final fazendaId = await _fazendaId();

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('farmacia_alertas');
      if (cache is List) {
        return cache
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => !apenasAbertos || e['aberto'] == true)
            .toList();
      }
      return [];
    }

    dynamic query = _client
        .from('farmacia_alertas')
        .select(
          '*, farmacia_produtos(nome, unidade, unidade_estoque, estoque, estoque_minimo)',
        )
        .eq('fazenda_id', fazendaId);

    if (apenasAbertos) {
      query = query.eq('aberto', true);
    }

    final result = await query.order('created_at', ascending: false);
    final lista = List<Map<String, dynamic>>.from(result);
    await _offlineStore.salvarCache('farmacia_alertas', lista);
    return lista;
  }

  Future<Map<String, dynamic>> criarProduto({
    required String nome,
    required String categoria,
    required String unidade,
    double estoque = 0,
    double estoqueMinimo = 0,
    DateTime? validade,
    String? principioAtivo,
    String? observacoes,
    double? dose,
    String? doseUnidade,
    double? pesoReferenciaKg,
    String? viaAplicacao,
    int? carenciaDias,
    String? fabricante,
    double? conteudoEmbalagem,
    String? unidadeEmbalagem,
    String? codigoLote,
  }) async {
    final fazendaId = await _fazendaId();

    if (nome.trim().isEmpty) {
      throw Exception('Informe o nome do produto.');
    }
    if (estoque < 0 || estoqueMinimo < 0) {
      throw Exception('O estoque não pode ser negativo.');
    }
    if (conteudoEmbalagem != null && conteudoEmbalagem <= 0) {
      throw Exception('O conteúdo da embalagem deve ser maior que zero.');
    }

    final id = const Uuid().v4();
    final unidadeFinal = unidade.trim().isEmpty ? 'unidade' : unidade.trim();
    final dados = <String, dynamic>{
      'id': id,
      'fazenda_id': fazendaId,
      'nome': nome.trim(),
      'categoria': categoria,
      'unidade': unidadeFinal,
      'unidade_estoque': unidadeFinal,
      'estoque': 0,
      'estoque_inicial': estoque,
      'estoque_inicial_movimentacao_id': estoque > 0 ? const Uuid().v4() : null,
      'estoque_minimo': estoqueMinimo,
      'validade': validade?.toIso8601String().split('T').first,
      'principio_ativo': _text(principioAtivo),
      'observacoes': _text(observacoes),
      'dose': dose,
      'dose_unidade': _text(doseUnidade),
      'peso_referencia_kg': pesoReferenciaKg,
      'via_aplicacao': _text(viaAplicacao),
      'carencia_dias': carenciaDias,
      'fabricante': _text(fabricante),
      'conteudo_embalagem': conteudoEmbalagem,
      'unidade_embalagem': _text(unidadeEmbalagem),
      'codigo_lote_inicial': _text(codigoLote),
      'validade_lote_inicial': validade?.toIso8601String().split('T').first,
    };

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'farmacia.produto.criar',
        dados: dados,
      );
      return dados;
    }

    final insertData = Map<String, dynamic>.from(dados)
      ..remove('estoque_inicial')
      ..remove('estoque_inicial_movimentacao_id')
      ..remove('codigo_lote_inicial')
      ..remove('validade_lote_inicial');

    final result = await _client
        .from('farmacia_produtos')
        .insert(insertData)
        .select()
        .single();

    if (estoque > 0) {
      await _client.rpc(
        'registrar_movimentacao_farmacia',
        params: {
          'p_id': const Uuid().v4(),
          'p_fazenda_id': fazendaId,
          'p_produto_id': id,
          'p_tipo': 'entrada',
          'p_quantidade': estoque,
          'p_data': DateTime.now().toIso8601String().split('T').first,
          'p_lote_id': null,
          'p_animal_id': null,
          'p_observacoes': 'Estoque inicial.',
          'p_codigo_lote': codigoLote,
          'p_validade': validade?.toIso8601String().split('T').first,
          'p_fabricante': fabricante,
          'p_farmacia_lote_id': null,
        },
      );
    }

    return Map<String, dynamic>.from(result);
  }

  Future<void> movimentar({
    required String produtoId,
    required String tipo,
    required double quantidade,
    String? loteId,
    String? animalId,
    String? observacoes,
    String? codigoLote,
    DateTime? validade,
    String? fabricante,
  }) async {
    final fazendaId = await _fazendaId();
    if (quantidade <= 0) {
      throw Exception('Informe uma quantidade maior que zero.');
    }

    final id = const Uuid().v4();
    final dados = <String, dynamic>{
      'id': id,
      'fazenda_id': fazendaId,
      'produto_id': produtoId,
      'tipo': tipo,
      'quantidade': quantidade,
      'data': DateTime.now().toIso8601String().split('T').first,
      'lote_id': loteId,
      'animal_id': animalId,
      'observacoes': _text(observacoes),
      'codigo_lote': _text(codigoLote),
      'validade': validade?.toIso8601String().split('T').first,
      'fabricante': _text(fabricante),
      'farmacia_lote_id': null,
    };

    if (!_connectivity.isOnline) {
      await OfflineSyncService.instance.enfileirar(
        tipo: 'farmacia.movimentacao',
        dados: dados,
      );
      return;
    }

    await _client.rpc(
      'registrar_movimentacao_farmacia',
      params: {
        'p_id': id,
        'p_fazenda_id': fazendaId,
        'p_produto_id': produtoId,
        'p_tipo': tipo,
        'p_quantidade': quantidade,
        'p_data': dados['data'],
        'p_lote_id': loteId,
        'p_animal_id': animalId,
        'p_observacoes': dados['observacoes'],
        'p_codigo_lote': codigoLote,
        'p_validade': dados['validade'],
        'p_fabricante': fabricante,
        'p_farmacia_lote_id': null,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listarMovimentacoes({
    required String loteId,
  }) async {
    final fazendaId = await _fazendaId();

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('farmacia_movimentos_$loteId');
      if (cache is List) {
        return cache
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    final result = await _client
        .from('farmacia_movimentacoes')
        .select(
          '*, farmacia_produtos(nome, unidade, unidade_estoque, categoria), '
          'farmacia_lotes(codigo_lote, validade), animais(brinco, nome)',
        )
        .eq('fazenda_id', fazendaId)
        .eq('lote_id', loteId)
        .order('data', ascending: false)
        .order('created_at', ascending: false);

    final lista = List<Map<String, dynamic>>.from(result);
    await _offlineStore.salvarCache(
      'farmacia_movimentos_$loteId',
      lista,
    );
    return lista;
  }

  String formatarQuantidade(dynamic valor, {String unidade = ''}) {
    final numero = _number(valor);
    final texto = numero % 1 == 0
        ? numero.toInt().toString()
        : numero.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
    return unidade.trim().isEmpty ? texto : texto + ' ' + unidade.trim();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _text(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
