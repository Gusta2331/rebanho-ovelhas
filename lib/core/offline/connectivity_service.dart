import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/supabase_config.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  Stream<bool> get statusStream => _controller.stream;

  bool _online = false;
  bool get isOnline => _online;
  int _probeGeneration = 0;

  Future<void> iniciar() async {
    final resultado = await _connectivity.checkConnectivity();
    await _atualizar(resultado);

    await _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((resultado) {
      unawaited(_atualizar(resultado));
    });
  }

  Future<void> _atualizar(List<ConnectivityResult> resultado) async {
    final temRede = resultado.any(
      (item) => item != ConnectivityResult.none,
    );

    final geracao = ++_probeGeneration;
    if (!temRede) {
      _definirOnline(false);
      return;
    }

    final uri = Uri.tryParse(SupabaseConfig.url);
    if (uri == null || uri.host.isEmpty) {
      _definirOnline(false);
      return;
    }
    try {
      final socket = await Socket.connect(uri.host, uri.hasPort ? uri.port : 443)
          .timeout(const Duration(seconds: 4));
      socket.destroy();
      if (geracao == _probeGeneration) _definirOnline(true);
    } catch (_) {
      if (geracao == _probeGeneration) _definirOnline(false);
    }
  }

  void _definirOnline(bool online) {
    if (_online == online) return;
    _online = online;
    _controller.add(_online);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
