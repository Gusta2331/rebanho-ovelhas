import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../flock/services/rebanho_service.dart';
import '../models/farm_transfer.dart';

class FarmTransferService {
  SupabaseClient get _client => SupabaseService.client;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  void _requireOnline() {
    if (!_connectivity.isOnline) {
      throw Exception(
        'Transferências entre fazendas exigem internet. Nenhuma alteração foi salva no aparelho.',
      );
    }
  }

  Future<String> _myFarmId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final farm = await _client
        .from('fazendas')
        .select('id')
        .eq('proprietario_id', user.id)
        .eq('ativo', true)
        .maybeSingle();
    if (farm == null) throw Exception('Nenhuma fazenda ativa foi encontrada.');
    return farm['id'].toString();
  }

  Future<String> getMyReceivingCode() async {
    _requireOnline();
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final farm = await _client
        .from('fazendas')
        .select('codigo_transferencia')
        .eq('proprietario_id', user.id)
        .eq('ativo', true)
        .maybeSingle();
    if (farm == null) throw Exception('Nenhuma fazenda ativa foi encontrada.');
    return farm['codigo_transferencia'].toString();
  }

  Future<Map<String, String>?> findDestination(String code) async {
    _requireOnline();
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    final response = await _client.rpc(
      'identificar_destino_transferencia',
      params: {'p_codigo_destino': normalized},
    );
    final rows = List<Map<String, dynamic>>.from(response as List);
    if (rows.isEmpty) return null;
    return {
      'id': rows.first['fazenda_id'].toString(),
      'nome': rows.first['nome'].toString(),
    };
  }

  Future<void> requestTransfer({
    required String animalId,
    required String destinationCode,
    String? observation,
    FarmTransferSaleData? sale,
  }) async {
    _requireOnline();
    await _client.rpc(
      'solicitar_transferencia_entre_fazendas',
      params: {
        'p_animal_id': animalId,
        'p_codigo_destino': destinationCode.trim(),
        'p_observacao': _nullIfBlank(observation),
        'p_tipo_operacao': sale == null ? 'transferencia' : 'venda',
        'p_data_venda': sale?.saleDate.toIso8601String().substring(0, 10),
        'p_tipo_venda': sale?.saleType,
        'p_peso_kg': sale?.weightKg,
        'p_preco_por_kg': sale?.pricePerKg,
        'p_valor_total': sale?.totalValue,
      },
    );
  }

  Future<List<FarmTransfer>> getSent() => _getTransfers(sent: true);
  Future<List<FarmTransfer>> getReceived() => _getTransfers(sent: false);

  Future<List<FarmTransfer>> _getTransfers({required bool sent}) async {
    _requireOnline();
    final farmId = await _myFarmId();
    final response = await _client
        .from('transferencias_entre_fazendas')
        .select()
        .eq(sent ? 'fazenda_origem_id' : 'fazenda_destino_id', farmId)
        .order('solicitado_em', ascending: false);
    return List<Map<String, dynamic>>.from(response)
        .map(FarmTransfer.fromMap)
        .toList();
  }

  Future<List<FarmTransferHistoryEntry>> getHistory(String transferId) async {
    _requireOnline();
    final response = await _client
        .from('transferencias_entre_fazendas_historico')
        .select('id, evento, detalhes, ocorrido_em')
        .eq('transferencia_id', transferId)
        .order('ocorrido_em');
    return List<Map<String, dynamic>>.from(response)
        .map(FarmTransferHistoryEntry.fromMap)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getDestinationFlocks() async {
    _requireOnline();
    return RebanhoService().getRebanhos(somenteAtivos: true);
  }

  Future<bool> hasTagConflict(int tag) async {
    _requireOnline();
    final farmId = await _myFarmId();
    final existing = await _client
        .from('animais')
        .select('id')
        .eq('fazenda_id', farmId)
        .eq('brinco', tag)
        .limit(1);
    return existing.isNotEmpty;
  }

  Future<void> respond({
    required String transferId,
    required bool accept,
    String? destinationFlockId,
    int? newTag,
  }) async {
    _requireOnline();
    await _client.rpc(
      'responder_transferencia_entre_fazendas',
      params: {
        'p_transferencia_id': transferId,
        'p_aceitar': accept,
        'p_rebanho_destino_id': destinationFlockId,
        'p_novo_brinco': newTag,
      },
    );
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class FarmTransferSaleData {
  final DateTime saleDate;
  final String saleType;
  final double? weightKg;
  final double? pricePerKg;
  final double totalValue;

  const FarmTransferSaleData({
    required this.saleDate,
    required this.saleType,
    required this.totalValue,
    this.weightKg,
    this.pricePerKg,
  });
}
