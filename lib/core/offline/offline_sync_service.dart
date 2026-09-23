import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'connectivity_service.dart';
import 'offline_operation.dart';
import 'offline_store.dart';

typedef OfflineOperationHandler = Future<void> Function(
  OfflineOperation operation,
);

class OfflineSyncService {
  OfflineSyncService._();

  static final OfflineSyncService instance = OfflineSyncService._();

  final OfflineStore _store = OfflineStore();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  final Map<String, OfflineOperationHandler> _handlers = {};

  StreamSubscription<bool>? _connectivitySubscription;
  bool _sincronizando = false;

  Future<void> iniciar() async {
    _registrarHandlersPadrao();
    await _connectivity.iniciar();

    await _connectivitySubscription?.cancel();
    _connectivitySubscription =
        _connectivity.statusStream.listen((online) {
      if (online) {
        unawaited(sincronizar());
      }
    });

    if (_connectivity.isOnline) {
      await sincronizar();
    }
  }

  void registrarHandler(
    String tipo,
    OfflineOperationHandler handler,
  ) {
    _handlers[tipo] = handler;
  }

  Future<void> enfileirar({
    required String tipo,
    required Map<String, dynamic> dados,
  }) async {
    await _store.adicionarOperacao(
      OfflineOperation(
        id: const Uuid().v4(),
        tipo: tipo,
        dados: dados,
        criadoEm: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<OfflineOperation>> pendentes() {
    return _store.listarOperacoes();
  }

  Future<void> sincronizar() async {
    if (_sincronizando || !_connectivity.isOnline) {
      return;
    }

    _sincronizando = true;

    try {
      final operacoes = await _store.listarOperacoes();

      for (final operacao in operacoes) {
        if (!_connectivity.isOnline) {
          break;
        }

        final handler = _handlers[operacao.tipo];

        if (handler == null) {
          continue;
        }

        try {
          await handler(operacao);
          await _store.removerOperacao(operacao.id);
        } catch (erro) {
          await _store.substituirOperacao(operacao.comErro(erro));
        }
      }
    } finally {
      _sincronizando = false;
    }
  }

  void _registrarHandlersPadrao() {
    registrarHandler('financeiro.criar', _sincronizarFinanceiroCriar);
    registrarHandler('financeiro.excluir', _sincronizarFinanceiroExcluir);
    registrarHandler('farmacia.produto.criar', _sincronizarProdutoCriar);
    registrarHandler('farmacia.movimentacao', _sincronizarMovimentacaoFarmacia);
    registrarHandler('manejo.criar', _sincronizarManejoCriar);
    registrarHandler('manejo.criar_lote', _sincronizarManejoLote);
    registrarHandler('manejo.atualizar', _sincronizarManejoAtualizar);
    registrarHandler('manejo.excluir', _sincronizarManejoExcluir);
    registrarHandler('manejo_programado.criar', _sincronizarManejoProgramadoCriar);
    registrarHandler('manejo_programado.concluir', _sincronizarManejoProgramadoConcluir);
    registrarHandler('manejo_programado.reprogramar', _sincronizarManejoProgramadoReprogramar);
    registrarHandler('manejo_programado.excluir', _sincronizarManejoProgramadoExcluir);
    registrarHandler('rebanho.criar', _sincronizarRebanhoCriar);
    registrarHandler('rebanho.atualizar', _sincronizarRebanhoAtualizar);
    registrarHandler('rebanho.status', _sincronizarRebanhoStatus);
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _sincronizarFinanceiroCriar(OfflineOperation op) async {
    await _client.from('financeiro_lancamentos').insert(op.dados);
  }

  Future<void> _sincronizarFinanceiroExcluir(OfflineOperation op) async {
    final d = op.dados;
    await _client.from('financeiro_lancamentos').delete()
        .eq('id', d['id']).eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarProdutoCriar(OfflineOperation op) async {
    await _client.from('farmacia_produtos').insert(op.dados);
  }

  Future<void> _sincronizarMovimentacaoFarmacia(OfflineOperation op) async {
    final d = op.dados;
    await _client.rpc('sincronizar_movimentacao_farmacia', params: {
      'p_id': d['id'], 'p_fazenda_id': d['fazenda_id'],
      'p_produto_id': d['produto_id'], 'p_tipo': d['tipo'],
      'p_quantidade': d['quantidade'], 'p_data': d['data'],
      'p_lote_id': d['lote_id'], 'p_animal_id': d['animal_id'],
      'p_observacoes': d['observacoes'],
    });
  }

  Future<void> _sincronizarManejoCriar(OfflineOperation op) async {
    await _client.from('manejos').insert(op.dados);
  }

  Future<void> _sincronizarManejoLote(OfflineOperation op) async {
    final itens = (op.dados['itens'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (itens.isNotEmpty) await _client.from('manejos').insert(itens);
  }

  Future<void> _sincronizarManejoAtualizar(OfflineOperation op) async {
    final d = Map<String, dynamic>.from(op.dados);
    final id = d.remove('id');
    final fazendaId = d.remove('fazenda_id');
    await _client.from('manejos').update(d)
        .eq('id', id).eq('fazenda_id', fazendaId);
  }

  Future<void> _sincronizarManejoExcluir(OfflineOperation op) async {
    final d = op.dados;
    await _client.from('manejos').delete()
        .eq('id', d['id']).eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarManejoProgramadoCriar(OfflineOperation op) async {
    final d = op.dados;
    await _client.rpc('sincronizar_manejo_programado', params: {
      'p_id': d['id'], 'p_fazenda_id': d['fazenda_id'],
      'p_tipo': d['tipo'], 'p_data_programada': d['data_programada'],
      'p_observacoes': d['observacoes'], 'p_animal_ids': d['animal_ids'],
      'p_vacina_id': d['vacina_id'], 'p_vacina_nome': d['vacina_nome'],
      'p_vacina_fabricante': d['vacina_fabricante'], 'p_dose': d['dose'],
      'p_dose_unidade': d['dose_unidade'], 'p_peso_referencia_kg': d['peso_referencia_kg'],
      'p_via_aplicacao': d['via_aplicacao'], 'p_validade': d['validade'],
      'p_carencia_dias': d['carencia_dias'], 'p_vermifugo_id': d['vermifugo_id'],
      'p_vermifugo_nome': d['vermifugo_nome'], 'p_medicamento_id': d['medicamento_id'],
      'p_medicamento_nome': d['medicamento_nome'],
    });
  }

  Future<void> _sincronizarManejoProgramadoConcluir(OfflineOperation op) async {
    final d = op.dados;
    await _client.from('manejos_programados').update({
      'concluido': true, 'realizado_em': d['realizado_em'],
    }).eq('id', d['id']).eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarManejoProgramadoReprogramar(OfflineOperation op) async {
    final d = op.dados;
    await _client.from('manejos_programados').update({
      'data_programada': d['data_programada'], 'concluido': false,
      'realizado_em': null,
    }).eq('id', d['id']).eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarManejoProgramadoExcluir(OfflineOperation op) async {
    final d = op.dados;
    await _client.from('manejos_programados').delete()
        .eq('id', d['id']).eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarRebanhoCriar(OfflineOperation op) async {
    await _client.from('rebanhos').insert(op.dados);
  }

  Future<void> _sincronizarRebanhoAtualizar(OfflineOperation op) async {
    final d = Map<String, dynamic>.from(op.dados);
    final id = d.remove('id');
    final fazendaId = d.remove('fazenda_id');
    await _client.from('rebanhos').update(d).eq('id', id).eq('fazenda_id', fazendaId);
  }

  Future<void> _sincronizarRebanhoStatus(OfflineOperation op) async {
    final d = op.dados;
    await _client.from('rebanhos').update({
      'ativo': d['ativo'], 'atualizado_em': d['atualizado_em'],
    }).eq('id', d['id']).eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> parar() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
