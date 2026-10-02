import '../../animals/models/animal.dart';
import '../../reproduction/models/reproducao.dart';
import '../../reproduction/models/reproducao_nascimento.dart';

class ReproductionReportData {
  final List<Reproducao> reproducoes;
  final Map<String, List<ReproducaoNascimento>> nascimentosPorReproducao;
  final Map<String, Animal> animaisPorId;
  final DateTime generatedAt;

  const ReproductionReportData({
    required this.reproducoes,
    required this.nascimentosPorReproducao,
    required this.animaisPorId,
    required this.generatedAt,
  });

  int get total => reproducoes.length;
  int get planejadas => reproducoes.where((r) => r.status == StatusReproducao.planejada).length;
  int get cobertas => reproducoes.where((r) => r.status == StatusReproducao.coberta).length;
  int get prenhes => reproducoes.where((r) => r.status == StatusReproducao.prenhe).length;
  int get naoPrenhes => reproducoes.where((r) => r.status == StatusReproducao.naoPrenhe).length;
  int get abortos => reproducoes.where((r) => r.status == StatusReproducao.abortou).length;
  int get partos => reproducoes.where((r) => r.status == StatusReproducao.partoRealizado).length;
  int get totalNascimentos => nascimentosPorReproducao.values.fold(0, (t, l) => t + l.length);
  int get femeasNascidas => nascimentosPorReproducao.values.expand((l) => l).where((n) => n.sexo == SexoNascimento.femea).length;
  int get machosNascidos => nascimentosPorReproducao.values.expand((l) => l).where((n) => n.sexo == SexoNascimento.macho).length;
}
