import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/reproducao.dart';

class ResumoReprodutivoChart extends StatelessWidget {
  final List<Reproducao> reproducoes;

  const ResumoReprodutivoChart({
    super.key,
    required this.reproducoes,
  });

  static const _status = <_StatusInfo>[
    _StatusInfo('Planejadas', StatusReproducao.planejada, Colors.blueGrey),
    _StatusInfo('Cobertas', StatusReproducao.coberta, Colors.blue),
    _StatusInfo('Prenhes', StatusReproducao.prenhe, Colors.green),
    _StatusInfo('Não prenhe', StatusReproducao.naoPrenhe, Colors.orange),
    _StatusInfo('Abortos', StatusReproducao.abortou, Colors.red),
    _StatusInfo('Partos', StatusReproducao.partoRealizado, Colors.teal),
    _StatusInfo('Encerradas', StatusReproducao.encerrada, Colors.grey),
  ];

  @override
  Widget build(BuildContext context) {
    final quantidades = <StatusReproducao, int>{
      for (final item in _status) item.status: 0,
    };

    for (final reproducao in reproducoes) {
      quantidades[reproducao.status] =
          (quantidades[reproducao.status] ?? 0) + 1;
    }

    final statusComRegistros = _status
        .where((item) => (quantidades[item.status] ?? 0) > 0)
        .toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Situação reprodutiva',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 142,
                  height: 142,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: 39,
                          sectionsSpace: 2,
                          sections: [
                            for (final item in statusComRegistros)
                              PieChartSectionData(
                                value: quantidades[item.status]!.toDouble(),
                                color: item.cor,
                                radius: 25,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${reproducoes.length}',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'registros',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in statusComRegistros)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: item.cor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  item.nome,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                '${quantidades[item.status]}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusInfo {
  final String nome;
  final StatusReproducao status;
  final Color cor;

  const _StatusInfo(this.nome, this.status, this.cor);
}
