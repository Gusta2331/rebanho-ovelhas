import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_store.dart';

import '../../../core/services/supabase_service.dart';
import '../models/farm.dart';

class FarmService {
  SupabaseClient get _client => SupabaseService.client;
  final OfflineStore _offlineStore = OfflineStore();
  final ConnectivityService _connectivity = ConnectivityService.instance;

  Future<Farm?> getMinhaFazenda() async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      return null;
    }

    const chaveCache = 'fazenda_atual';

    if (!_connectivity.isOnline) {
      final cache = await _offlineStore.lerCache(chaveCache);
      if (cache is Map) {
        return Farm.fromMap(Map<String, dynamic>.from(cache));
      }
      return null;
    }

    try {
      final resultado = await _client
          .from('fazendas')
          .select()
          .eq('proprietario_id', usuario.id)
          .eq('ativo', true)
          .maybeSingle();

      if (resultado == null) return null;

      await _offlineStore.salvarCache(chaveCache, resultado);
      return Farm.fromMap(resultado);
    } catch (_) {
      final cache = await _offlineStore.lerCache(chaveCache);
      if (cache is Map) {
        return Farm.fromMap(Map<String, dynamic>.from(cache));
      }
      rethrow;
    }
  }

  Future<Farm> criarFazenda({
    required String nome,
    String? cidade,
    String? estado,
    String? endereco,
    String? telefone,
    String? observacoes,
  }) async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    final fazenda = await _client
        .from('fazendas')
        .insert({
          'nome': nome.trim(),
          'proprietario_id': usuario.id,
          'nome_proprietario': usuario.userMetadata?['nome'],
          'telefone': telefone?.trim().isEmpty == true
              ? null
              : telefone?.trim(),
          'cidade': cidade?.trim().isEmpty == true ? null : cidade?.trim(),
          'estado': estado?.trim().isEmpty == true ? null : estado?.trim(),
          'endereco': endereco?.trim().isEmpty == true
              ? null
              : endereco?.trim(),
          'observacoes': observacoes?.trim().isEmpty == true
              ? null
              : observacoes?.trim(),
        })
        .select()
        .single();

    return Farm.fromMap(fazenda);
  }

  Future<Farm> atualizarFazenda({
    required String id,
    String? nome,
    String? cidade,
    String? estado,
    String? endereco,
    String? telefone,
    String? observacoes,
  }) async {
    final dados = <String, dynamic>{
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };

    if (nome != null) {
      dados['nome'] = nome.trim();
    }

    if (cidade != null) {
      dados['cidade'] = cidade.trim().isEmpty ? null : cidade.trim();
    }

    if (estado != null) {
      dados['estado'] = estado.trim().isEmpty ? null : estado.trim();
    }

    if (endereco != null) {
      dados['endereco'] = endereco.trim().isEmpty ? null : endereco.trim();
    }

    if (telefone != null) {
      dados['telefone'] = telefone.trim().isEmpty ? null : telefone.trim();
    }

    if (observacoes != null) {
      dados['observacoes'] = observacoes.trim().isEmpty
          ? null
          : observacoes.trim();
    }

    final fazenda = await _client
        .from('fazendas')
        .update(dados)
        .eq('id', id)
        .select()
        .single();

    return Farm.fromMap(fazenda);
  }
}
