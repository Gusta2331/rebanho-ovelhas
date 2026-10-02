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

  Future<Map<String, List<ComposicaoRacial>>> listarPorAnimais(List<String> animalIds) async {
    if (animalIds.isEmpty) return {};
    final resultados = <String, List<ComposicaoRacial>>{};
    await Future.wait(animalIds.map((id) async {
      resultados[id] = await listarPorAnimal(id);
    }));
    return resultados;
  }

  Future<List<ComposicaoRacial>> calcularPelosPais({
    required String maeId,
    required String paiId,
  }) async {
    final mae = await _calcularAnimal(maeId, <String>{});
    final pai = await _calcularAnimal(paiId, <String>{});

    if (mae.isEmpty || pai.isEmpty) {
      return [];
    }

    final resultado = <String, double>{};
    for (final entry in mae.entries) {
      resultado[entry.key] = (resultado[entry.key] ?? 0) + entry.value / 2;
    }
    for (final entry in pai.entries) {
      resultado[entry.key] = (resultado[entry.key] ?? 0) + entry.value / 2;
    }

    final normalizado = _normalizar(resultado);
    if (normalizado.isEmpty) return [];

    final ids = normalizado.keys.toList();
    final racas = await _client
        .from('racas')
        .select('id, nome')
        .inFilter('id', ids);

    final nomes = <String, String>{
      for (final row in racas as List)
        row['id'].toString(): row['nome'].toString(),
    };

    final composicao = normalizado.entries
        .where((entry) => entry.value > 0.0001)
        .map(
          (entry) => ComposicaoRacial(
            racaId: entry.key,
            racaNome: nomes[entry.key] ?? 'Raça',
            percentual: entry.value,
            automatico: true,
          ),
        )
        .toList()
      ..sort((a, b) => b.percentual.compareTo(a.percentual));

    return composicao;
  }

  Future<void> salvarComposicaoManual({
    required String animalId,
    required List<Map<String, dynamic>> composicoes,
  }) async {
    if (composicoes.isEmpty) {
      throw Exception('Informe pelo menos uma raça na composição.');
    }

    final dados = <Map<String, dynamic>>[];

    for (final item in composicoes) {
      final nome = item['raca_nome']?.toString().trim() ?? '';
      final percentual = item['percentual'] is num
          ? (item['percentual'] as num).toDouble()
          : double.tryParse(
              item['percentual']?.toString().replaceAll(',', '.') ?? '',
            ) ?? 0;

      if (nome.isEmpty || percentual <= 0) {
        throw Exception('Informe uma raça e um percentual válido.');
      }

      final raca = await _client
          .from('racas')
          .select('id')
          .eq('nome', nome)
          .eq('ativo', true)
          .limit(1)
          .maybeSingle();

      if (raca == null) {
        throw Exception('A raça "$nome" não foi encontrada na biblioteca.');
      }

      dados.add({
        'animal_id': animalId,
        'raca_id': raca['id'].toString(),
        'percentual': percentual,
        'automatico': false,
      });
    }

    final total = dados.fold<double>(
      0,
      (soma, item) => soma + (item['percentual'] as double),
    );

    if ((total - 100).abs() > 0.01) {
      throw Exception(
        'A composição manual precisa totalizar 100%. '
        'Atualmente está em ${total.toStringAsFixed(1)}%.',
      );
    }

    await _client
        .from('animal_composicoes_raciais')
        .delete()
        .eq('animal_id', animalId);

    await _client.from('animal_composicoes_raciais').insert(dados);
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
      return resultado;
    }
    if (paisConhecidos == 2) return _normalizar(resultado);
    return resultado;
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
