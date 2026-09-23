import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';
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
      throw Exception('Sem internet e a fazenda ainda não foi salva neste aparelho.');
    }

    try {
      final farm = await _client.from('fazendas').select('id')
          .eq('proprietario_id', user.id).eq('ativo', true).maybeSingle();
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
      if (cache is List) return cache.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return [];
    }
    final result = await _client.from('farmacia_produtos').select('*')
        .eq('fazenda_id', fazendaId).eq('ativo', true).order('nome');
    final lista = List<Map<String, dynamic>>.from(result);
    await _offlineStore.salvarCache('farmacia_produtos', lista);
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
  }) async {
    final fazendaId = await _fazendaId();
    if (nome.trim().isEmpty) throw Exception('Informe o nome do produto.');
    if (estoque < 0 || estoqueMinimo < 0) {
      throw Exception('O estoque não pode ser negativo.');
    }

    final result = await _client.from('farmacia_produtos').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'nome': nome.trim(),
      'categoria': categoria,
      'unidade': unidade.trim().isEmpty ? 'unidade' : unidade.trim(),
      'estoque': estoque,
      'estoque_minimo': estoqueMinimo,
      'validade': validade?.toIso8601String().split('T').first,
      'principio_ativo': _text(principioAtivo),
      'observacoes': _text(observacoes),
    }).select().single();

    return Map<String, dynamic>.from(result);
  }

  Future<void> movimentar({
    required String produtoId,
    required String tipo,
    required double quantidade,
    String? loteId,
    String? animalId,
    String? observacoes,
  }) async {
    final fazendaId = await _fazendaId();
    if (quantidade <= 0) throw Exception('Informe uma quantidade maior que zero.');

    final produto = await _client.from('farmacia_produtos').select('estoque')
        .eq('id', produtoId).eq('fazenda_id', fazendaId).maybeSingle();
    if (produto == null) throw Exception('Produto não encontrado.');

    final atual = _number(produto['estoque']);
    final novo = tipo == 'entrada' ? atual + quantidade : atual - quantidade;
    if (novo < 0) throw Exception('Estoque insuficiente.');

    await _client.from('farmacia_produtos').update({
      'estoque': novo,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', produtoId).eq('fazenda_id', fazendaId);

    await _client.from('farmacia_movimentacoes').insert({
      'id': const Uuid().v4(),
      'fazenda_id': fazendaId,
      'produto_id': produtoId,
      'tipo': tipo,
      'quantidade': quantidade,
      'data': DateTime.now().toIso8601String().split('T').first,
      'lote_id': loteId,
      'animal_id': animalId,
      'observacoes': _text(observacoes),
    });
  }

  Future<List<Map<String, dynamic>>> listarMovimentacoes({
    required String loteId,
  }) async {
    final fazendaId = await _fazendaId();
    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache('farmacia_movimentos_' + loteId);
      if (cache is List) return cache.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return [];
    }
    final result = await _client.from('farmacia_movimentacoes').select(
      '*, farmacia_produtos(nome, unidade, categoria), animais(brinco, nome)',
    ).eq('fazenda_id', fazendaId).eq('lote_id', loteId)
      .order('data', ascending: false).order('created_at', ascending: false);
    final lista = List<Map<String, dynamic>>.from(result);
    await _offlineStore.salvarCache('farmacia_movimentos_' + loteId, lista);
    return lista;
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
