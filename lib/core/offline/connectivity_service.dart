import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  Stream<bool> get statusStream => _controller.stream;

  bool _online = true;
  bool get isOnline => _online;

  Future<void> iniciar() async {
    final resultado = await _connectivity.checkConnectivity();
    _atualizar(resultado);

    await _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(_atualizar);
  }

  void _atualizar(List<ConnectivityResult> resultado) {
    final online = resultado.any(
      (item) => item != ConnectivityResult.none,
    );

    if (_online == online) {
      return;
    }

    _online = online;
    _controller.add(_online);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
