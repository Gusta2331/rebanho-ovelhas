import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offline_operation.dart';

class OfflineStore {
  static const _prefixoCache = 'offline_cache_';
  static const _chaveFila = 'offline_operations';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> salvarCache(String chave, Object valor) async {
    final prefs = await _prefs;
    await prefs.setString('$_prefixoCache$chave', jsonEncode(valor));
  }

  Future<dynamic> lerCache(String chave) async {
    final prefs = await _prefs;
    final texto = prefs.getString('$_prefixoCache$chave');

    if (texto == null || texto.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(texto);
    } catch (_) {
      return null;
    }
  }

  Future<void> removerCache(String chave) async {
    final prefs = await _prefs;
    await prefs.remove('$_prefixoCache$chave');
  }

  Future<List<OfflineOperation>> listarOperacoes() async {
    final prefs = await _prefs;
    final itens = prefs.getStringList(_chaveFila) ?? [];

    final operacoes = <OfflineOperation>[];

    for (final item in itens) {
      try {
        operacoes.add(
          OfflineOperation.fromJson(
            Map<String, dynamic>.from(jsonDecode(item) as Map),
          ),
        );
      } catch (_) {
        // Remove entradas corrompidas na próxima gravação.
      }
    }

    return operacoes;
  }

  Future<void> adicionarOperacao(OfflineOperation operacao) async {
    final operacoes = await listarOperacoes();
    operacoes.add(operacao);
    await _salvarOperacoes(operacoes);
  }

  Future<void> substituirOperacao(OfflineOperation operacao) async {
    final operacoes = await listarOperacoes();
    final index = operacoes.indexWhere((item) => item.id == operacao.id);

    if (index == -1) {
      return;
    }

    operacoes[index] = operacao;
    await _salvarOperacoes(operacoes);
  }

  Future<void> removerOperacao(String id) async {
    final operacoes = await listarOperacoes();
    operacoes.removeWhere((item) => item.id == id);
    await _salvarOperacoes(operacoes);
  }

  Future<void> _salvarOperacoes(List<OfflineOperation> operacoes) async {
    final prefs = await _prefs;

    await prefs.setStringList(
      _chaveFila,
      operacoes.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> limparDadosOffline() async {
    final prefs = await _prefs;
    final chaves = prefs.getKeys()
        .where((key) => key.startsWith(_prefixoCache))
        .toList();

    for (final chave in chaves) {
      await prefs.remove(chave);
    }

    await prefs.remove(_chaveFila);
  }
}
