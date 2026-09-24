import 'dart:async';
import 'dart:io';

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
    _connectivitySubscription = _connectivity.statusStream.listen((online) {
      if (online) {
        unawaited(sincronizar());
      }
    });

    if (_connectivity.isOnline) {
      await sincronizar();
    }
  }

  void registrarHandler(String tipo, OfflineOperationHandler handler) {
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
          if (operacao.ultimoErro == null) {
            await _store.substituirOperacao(
              operacao.comErro(
                StateError(
                  'Não existe sincronizador para a operação ${operacao.tipo}.',
                ),
              ),
            );
          }
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
    registrarHandler(
      'manejo_programado.criar',
      _sincronizarManejoProgramadoCriar,
    );
    registrarHandler(
      'manejo_programado.concluir',
      _sincronizarManejoProgramadoConcluir,
    );
    registrarHandler(
      'manejo_programado.reprogramar',
      _sincronizarManejoProgramadoReprogramar,
    );
    registrarHandler(
      'manejo_programado.excluir',
      _sincronizarManejoProgramadoExcluir,
    );
    registrarHandler('rebanho.criar', _sincronizarRebanhoCriar);
    registrarHandler('rebanho.atualizar', _sincronizarRebanhoAtualizar);
    registrarHandler('rebanho.status', _sincronizarRebanhoStatus);
    registrarHandler('animal.venda', _sincronizarVendaAnimal);
    registrarHandler('animal.criar', _sincronizarAnimalCriar);
    registrarHandler('animal.atualizar', _sincronizarAnimalAtualizar);
    registrarHandler('animal.excluir', _sincronizarAnimalExcluir);
    registrarHandler('animal.transferir', _sincronizarTransferenciaAnimal);
    registrarHandler('reproducao.criar', _sincronizarReproducaoCriar);
    registrarHandler('reproducao.atualizar', _sincronizarReproducaoAtualizar);
    registrarHandler('reproducao.nascimento', _sincronizarReproducaoNascimento);
    registrarHandler('reproducao.monta', _sincronizarReproducaoMonta);
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<String?> _enviarFotoAnimal(Map<String, dynamic> dados) async {
    final caminho = dados['foto_path']?.toString().trim();
    if (caminho == null || caminho.isEmpty) {
      final url = dados['foto_url']?.toString().trim();
      return url == null || url.isEmpty || !url.startsWith('http') ? null : url;
    }
    if (caminho.startsWith('http://') || caminho.startsWith('https://'))
      return caminho;
    final arquivo = File(caminho);
    if (!await arquivo.exists())
      throw Exception(
        'A foto local do animal não está mais disponível para sincronizar.',
      );
    final extensao = caminho.split('.').last.toLowerCase();
    final contentType = switch (extensao) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    final fazendaId = dados['fazenda_id'].toString();
    final animalId = dados['id'].toString();
    final destino = '$fazendaId/$animalId.$extensao';
    await _client.storage
        .from('animal-fotos')
        .upload(
          destino,
          arquivo,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from('animal-fotos').getPublicUrl(destino);
  }

  Future<String?> _obterOuCriarRaca(String fazendaId, String? nome) async {
    final texto = nome?.trim() ?? '';
    if (texto.isEmpty) return null;
    final encontrada = await _client
        .from('racas')
        .select('id')
        .eq('fazenda_id', fazendaId)
        .eq('nome', texto)
        .eq('ativo', true)
        .maybeSingle();
    if (encontrada != null) return encontrada['id']?.toString();
    final criada = await _client
        .from('racas')
        .insert({
          'id': const Uuid().v4(),
          'fazenda_id': fazendaId,
          'nome': texto,
          'ativo': true,
        })
        .select('id')
        .single();
    return criada['id']?.toString();
  }

  Future<void> _sincronizarAnimalCriar(OfflineOperation operation) async {
    final dados = Map<String, dynamic>.from(operation.dados);
    dados['foto_url'] = await _enviarFotoAnimal(dados);
    dados.remove('foto_path');
    await _client.rpc('sincronizar_animal', params: {'p_dados': dados});
  }

  Future<void> _sincronizarAnimalAtualizar(OfflineOperation operation) async {
    final dados = Map<String, dynamic>.from(operation.dados);
    final fazendaId = dados['fazenda_id'].toString();
    final racaId = await _obterOuCriarRaca(
      fazendaId,
      dados['raca_nome']?.toString(),
    );
    dados['foto_url'] = await _enviarFotoAnimal(dados);
    await _client.rpc(
      'atualizar_animal_com_origem',
      params: {
        'p_animal_id': dados['id'],
        'p_rebanho_id': dados['rebanho_id'],
        'p_brinco': dados['brinco'],
        'p_nome': dados['nome'],
        'p_sexo': dados['sexo'],
        'p_raca_id': racaId,
        'p_data_nascimento': dados['data_nascimento'],
        'p_status': dados['status'],
        'p_data_entrada': dados['data_entrada'],
        'p_data_saida': dados['data_saida'],
        'p_observacoes': dados['observacoes'],
        'p_foto_url': dados['foto_url'],
        'p_mae_id': dados['mae_id'],
        'p_pai_id': dados['pai_id'],
        'p_origem': dados['origem'],
        'p_data_aquisicao': dados['data_aquisicao'],
        'p_valor_aquisicao': dados['valor_aquisicao'],
        'p_vendedor': dados['vendedor'],
        'p_denticao': dados['denticao'],
        'p_denticao_data': dados['denticao_data'],
        'p_denticao_observacoes': dados['denticao_observacoes'],
      },
    );
  }

  Future<void> _sincronizarAnimalExcluir(OfflineOperation operation) async {
    await _client.rpc(
      'excluir_animal_e_historico',
      params: {'p_animal_id': operation.dados['id']},
    );
  }

  Future<void> _sincronizarReproducaoCriar(OfflineOperation operation) async {
    await _insertIdempotente('reproducoes', operation.dados);
  }

  Future<void> _sincronizarReproducaoAtualizar(
    OfflineOperation operation,
  ) async {
    final dados = Map<String, dynamic>.from(operation.dados);
    final id = dados.remove('id');
    final fazendaId = dados.remove('fazenda_id');
    await _client
        .from('reproducoes')
        .update(dados)
        .eq('id', id)
        .eq('fazenda_id', fazendaId);
  }

  Future<void> _sincronizarReproducaoNascimento(
    OfflineOperation operation,
  ) async {
    final dados = Map<String, dynamic>.from(operation.dados);
    final fazendaId = dados.remove('fazenda_id');
    await _insertIdempotente('reproducao_nascimentos', dados);
    await _client
        .from('reproducoes')
        .update({
          'data_parto': dados['data_nascimento'],
          'status': 'parto_realizado',
          'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', dados['reproducao_id'])
        .eq('fazenda_id', fazendaId);
  }

  Future<void> _sincronizarReproducaoMonta(OfflineOperation operation) async {
    final dados = Map<String, dynamic>.from(operation.dados);
    final fazendaId = dados.remove('fazenda_id');
    await _insertIdempotente('reproducao_coberturas', dados);
    final reproducao = await _client
        .from('reproducoes')
        .select('status, data_cobertura, data_previsao_parto')
        .eq('id', dados['reproducao_id'])
        .eq('fazenda_id', fazendaId)
        .maybeSingle();
    if (reproducao != null && reproducao['status'] == 'planejada') {
      await _client
          .from('reproducoes')
          .update({
            'status': 'coberta',
            if (reproducao['data_cobertura'] == null)
              'data_cobertura': dados['data_cobertura'],
            if (reproducao['data_previsao_parto'] == null)
              'data_previsao_parto':
                  DateTime.parse(dados['data_cobertura'].toString())
                      .add(const Duration(days: 150))
                      .toIso8601String()
                      .split('T')
                      .first,
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', dados['reproducao_id'])
          .eq('fazenda_id', fazendaId);
    }
  }

  Future<void> _sincronizarTransferenciaAnimal(
    OfflineOperation operation,
  ) async {
    final dados = Map<String, dynamic>.from(operation.dados);
    final fazendaId = dados['fazenda_id'];
    await _insertIdempotente('animal_transferencias', dados);
    await _client
        .from('animais')
        .update({
          'rebanho_id': dados['rebanho_destino_id'],
          'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', dados['animal_id'])
        .eq('fazenda_id', fazendaId);
  }

  Future<void> _sincronizarFinanceiroCriar(OfflineOperation op) async {
    await _insertIdempotente('financeiro_lancamentos', op.dados);
  }

  Future<void> _sincronizarFinanceiroExcluir(OfflineOperation op) async {
    final d = op.dados;
    await _client
        .from('financeiro_lancamentos')
        .delete()
        .eq('id', d['id'])
        .eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarProdutoCriar(OfflineOperation op) async {
    await _insertIdempotente('farmacia_produtos', op.dados);
  }

  Future<void> _sincronizarMovimentacaoFarmacia(OfflineOperation op) async {
    final d = op.dados;
    await _client.rpc(
      'sincronizar_movimentacao_farmacia',
      params: {
        'p_id': d['id'],
        'p_fazenda_id': d['fazenda_id'],
        'p_produto_id': d['produto_id'],
        'p_tipo': d['tipo'],
        'p_quantidade': d['quantidade'],
        'p_data': d['data'],
        'p_lote_id': d['lote_id'],
        'p_animal_id': d['animal_id'],
        'p_observacoes': d['observacoes'],
      },
    );
  }

  Future<void> _sincronizarManejoCriar(OfflineOperation op) async {
    final dados = Map<String, dynamic>.from(op.dados);
    if (dados['farmacia_produto_id']?.toString().isNotEmpty == true) {
      await _client.rpc(
        'registrar_manejo_com_estoque',
        params: {
          'p_dados': dados,
          'p_quantidade': dados['farmacia_quantidade'] ?? dados['dose'],
        },
      );
      return;
    }
    await _insertIdempotente('manejos', dados);
  }

  Future<void> _sincronizarManejoLote(OfflineOperation op) async {
    final itens = (op.dados['itens'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (itens.isEmpty) return;

    final usaFarmacia = itens.any(
      (item) => item['farmacia_produto_id']?.toString().isNotEmpty == true,
    );

    if (usaFarmacia) {
      await _client.rpc(
        'registrar_manejos_com_estoque',
        params: {'p_itens': itens},
      );
      return;
    }

    try {
      await _client.from('manejos').insert(itens);
    } catch (_) {
      for (final item in itens) {
        final id = item['id'];
        final existe = await _client
            .from('manejos')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existe == null) rethrow;
      }
    }
  }

  Future<void> _sincronizarManejoAtualizar(OfflineOperation op) async {
    final d = Map<String, dynamic>.from(op.dados);
    final id = d.remove('id');
    final fazendaId = d.remove('fazenda_id');
    await _client.rpc(
      'atualizar_manejo_com_estoque',
      params: {
        'p_id': id,
        'p_fazenda_id': fazendaId,
        'p_dados': {'id': id, 'fazenda_id': fazendaId, ...d},
      },
    );
  }

  Future<void> _sincronizarManejoExcluir(OfflineOperation op) async {
    final d = op.dados;
    await _client.rpc(
      'excluir_manejo_com_estoque',
      params: {
        'p_id': d['id'],
        'p_fazenda_id': d['fazenda_id'],
      },
    );
  }

  Future<void> _sincronizarManejoProgramadoCriar(OfflineOperation op) async {
    final d = op.dados;
    await _client.rpc(
      'sincronizar_manejo_programado',
      params: {
        'p_id': d['id'],
        'p_fazenda_id': d['fazenda_id'],
        'p_tipo': d['tipo'],
        'p_data_programada': d['data_programada'],
        'p_observacoes': d['observacoes'],
        'p_animal_ids': d['animal_ids'],
        'p_outro_nome': d['outro_nome'],
        'p_vacina_id': d['vacina_id'],
        'p_vacina_nome': d['vacina_nome'],
        'p_vacina_fabricante': d['vacina_fabricante'],
        'p_dose': d['dose'],
        'p_dose_unidade': d['dose_unidade'],
        'p_peso_referencia_kg': d['peso_referencia_kg'],
        'p_via_aplicacao': d['via_aplicacao'],
        'p_validade': d['validade'],
        'p_carencia_dias': d['carencia_dias'],
        'p_vermifugo_id': d['vermifugo_id'],
        'p_vermifugo_nome': d['vermifugo_nome'],
        'p_medicamento_id': d['medicamento_id'],
        'p_medicamento_nome': d['medicamento_nome'],
      },
    );
  }

  Future<void> _sincronizarManejoProgramadoConcluir(OfflineOperation op) async {
    final d = op.dados;
    await _client
        .from('manejos_programados')
        .update({'concluido': true, 'realizado_em': d['realizado_em']})
        .eq('id', d['id'])
        .eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarManejoProgramadoReprogramar(
    OfflineOperation op,
  ) async {
    final d = op.dados;
    await _client
        .from('manejos_programados')
        .update({
          'data_programada': d['data_programada'],
          'concluido': false,
          'realizado_em': null,
        })
        .eq('id', d['id'])
        .eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarManejoProgramadoExcluir(OfflineOperation op) async {
    final d = op.dados;
    await _client
        .from('manejos_programados')
        .delete()
        .eq('id', d['id'])
        .eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> _sincronizarVendaAnimal(OfflineOperation op) async {
    final d = op.dados;
    try {
      await _client.rpc(
        'vender_animal',
        params: {
          'p_animal_id': d['animal_id'],
          'p_lote_id': d['lote_id'],
          'p_data_venda': d['data_venda'],
          'p_tipo_venda': d['tipo_venda'],
          'p_peso_kg': d['peso_kg'],
          'p_preco_por_kg': d['preco_por_kg'],
          'p_valor_total': d['valor_total'],
          'p_comprador': d['comprador'],
          'p_observacoes': d['observacoes'],
        },
      );
    } catch (erro) {
      final existente = await _client
          .from('vendas_animais')
          .select(
            'animal_id, lote_id, data_venda, tipo_venda, peso_kg, preco_por_kg, valor_total',
          )
          .eq('animal_id', d['animal_id'])
          .maybeSingle();

      if (existente == null) {
        rethrow;
      }

      final mesmaVenda =
          existente['lote_id']?.toString() == d['lote_id']?.toString() &&
          existente['data_venda']?.toString() == d['data_venda']?.toString() &&
          existente['tipo_venda']?.toString() == d['tipo_venda']?.toString() &&
          existente['valor_total'].toString() == d['valor_total'].toString();

      if (!mesmaVenda) {
        rethrow;
      }
    }
  }

  Future<void> _sincronizarRebanhoCriar(OfflineOperation op) async {
    await _insertIdempotente('rebanhos', op.dados);
  }

  Future<void> _insertIdempotente(
    String tabela,
    Map<String, dynamic> dados,
  ) async {
    try {
      await _client.from(tabela).insert(dados);
    } catch (erro) {
      final existe = await _client
          .from(tabela)
          .select('id')
          .eq('id', dados['id'])
          .maybeSingle();
      if (existe == null) rethrow;
    }
  }

  Future<void> _sincronizarRebanhoAtualizar(OfflineOperation op) async {
    final d = Map<String, dynamic>.from(op.dados);
    final id = d.remove('id');
    final fazendaId = d.remove('fazenda_id');
    await _client
        .from('rebanhos')
        .update(d)
        .eq('id', id)
        .eq('fazenda_id', fazendaId);
  }

  Future<void> _sincronizarRebanhoStatus(OfflineOperation op) async {
    final d = op.dados;
    await _client
        .from('rebanhos')
        .update({'ativo': d['ativo'], 'atualizado_em': d['atualizado_em']})
        .eq('id', d['id'])
        .eq('fazenda_id', d['fazenda_id']);
  }

  Future<void> parar() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
