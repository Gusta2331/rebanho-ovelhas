import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/composicao_racial.dart';

class ComposicaoRacialService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<ComposicaoRacial>> listarPorAnimal(String animalId) async {
    final rows = await _client.from('animal_composicoes_raciais')
      .select('raca_id, percentual, automatico, racas(nome)')
      .eq('animal_id', animalId).order('percentual', ascending: false);
    return (rows as List).map((row) {
      final raca = row['racas'];
      return ComposicaoRacial(
        racaId: row['raca_id'].toString(),
        racaNome: raca is Map ? raca['nome'].toString() : 'Raça',
        percentual: _numero(row['percentual']),
        automatico: row['automatico'] == true,
      );
    }).toList();
  }

  Future<void> recalcularAnimal(String animalId) async {
    final composicao = await _calcularAnimal(animalId, <String>{});
    if (composicao.isEmpty) return;
    await _client.from('animal_composicoes_raciais').delete().eq('animal_id', animalId);
    await _client.from('animal_composicoes_raciais').insert(
      composicao.entries.where((e) => e.value > 0.0001).map((e) => {
        'animal_id': animalId,
        'raca_id': e.key,
        'percentual': double.parse(e.value.toStringAsFixed(3)),
        'automatico': true,
      }).toList(),
    );
  }

  Future<Map<String, double>> _calcularAnimal(String animalId, Set<String> visitados) async {
    if (!visitados.add(animalId) || visitados.length > 20) return {};
    final animal = await _client.from('animais').select('id, raca_id, mae_id, pai_id').eq('id', animalId).maybeSingle();
    if (animal == null) return {};

    final resultado = <String, double>{};
    var paisConhecidos = 0;
    for (final parentId in [animal['mae_id']?.toString(), animal['pai_id']?.toString()]) {
      if (parentId == null || parentId.isEmpty) continue;
      final parent = await _calcularAnimal(parentId, Set<String>.from(visitados));
      if (parent.isEmpty) continue;
      paisConhecidos++;
      parent.forEach((racaId, percentual) {
        resultado[racaId] = (resultado[racaId] ?? 0) + percentual / 2;
      });
    }

    if (paisConhecidos == 0) {
      final racaId = animal['raca_id']?.toString();
      if (racaId != null && racaId.isNotEmpty) resultado[racaId] = 100;
    }
    return _normalizar(resultado);
  }

  Map<String, double> _normalizar(Map<String, double> valores) {
    final total = valores.values.fold<double>(0, (soma, valor) => soma + valor);
    if (total <= 0) return {};
    final fator = 100 / total;
    return valores.map((key, value) => MapEntry(key, value * fator));
  }

  double _numero(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }
}
