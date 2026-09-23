import 'dart:async';

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

  Future<void> parar() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
