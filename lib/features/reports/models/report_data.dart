import '../../animals/models/animal.dart';
import '../../animals/models/composicao_racial.dart';

class ReportData {
  final List<Animal> animals;
  final DateTime generatedAt;
  final Map<String, List<ComposicaoRacial>> composicoesPorAnimal;

  const ReportData({
    required this.animals,
    required this.generatedAt,
    this.composicoesPorAnimal = const {},
  });

  int get total => animals.length;
  int get ativos => _count(StatusAnimal.ativo);
  int get vendidos => _count(StatusAnimal.vendido);
  int get mortos => _count(StatusAnimal.morto);
  int get descartados => _count(StatusAnimal.descartado);
  int get femeas => animals.where((a) => a.sexo == SexoAnimal.femea).length;
  int get machos => animals.where((a) => a.sexo == SexoAnimal.macho).length;

  Map<String, int> get porRaca {
    final result = <String, int>{};
    for (final animal in animals) {
      final raca = animal.raca.trim().isEmpty ? 'Não informada' : animal.raca.trim();
      result[raca] = (result[raca] ?? 0) + 1;
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  double percentualRaca(int quantidade) =>
      total == 0 ? 0 : (quantidade / total) * 100;

  int _count(StatusAnimal status) =>
      animals.where((animal) => animal.status == status).length;
}
