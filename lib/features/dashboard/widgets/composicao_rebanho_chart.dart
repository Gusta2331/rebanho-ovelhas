import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ComposicaoRebanhoChart extends StatelessWidget {
  final int femeas;
  final int machos;
  final bool carregando;

  const ComposicaoRebanhoChart({
    super.key,
    required this.femeas,
    required this.machos,
    required this.carregando,
  });

  @override
  Widget build(BuildContext context) {
    final total = femeas + machos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Composição do rebanho',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Distribuição dos animais ativos por sexo',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (carregando)
              const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Cadastre animais para visualizar o gráfico.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 34,
                        sectionsSpace: 3,
                        sections: [
                          if (femeas > 0)
                            PieChartSectionData(
                              value: femeas.toDouble(),
                              title: '$femeas',
                              color: AppTheme.primaryColor,
                              radius: 48,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (machos > 0)
                            PieChartSectionData(
                              value: machos.toDouble(),
                              title: '$machos',
                              color: const Color(0xFFF2B544),
                              radius: 48,
                              titleStyle: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Legenda(
                          cor: AppTheme.primaryColor,
                          titulo: 'Fêmeas',
                          quantidade: femeas,
                          percentual: femeas / total * 100,
                        ),
                        const SizedBox(height: 14),
                        _Legenda(
                          cor: const Color(0xFFF2B544),
                          titulo: 'Machos',
                          quantidade: machos,
                          percentual: machos / total * 100,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: $total animais',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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

class _Legenda extends StatelessWidget {
  final Color cor;
  final String titulo;
  final int quantidade;
  final double percentual;

  const _Legenda({
    required this.cor,
    required this.titulo,
    required this.quantidade,
    required this.percentual,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          '$titulo: $quantidade',
          style: const TextStyle(fontSize: 13),
        ),
      ),
      Text(
        '${percentual.toStringAsFixed(0)}%',
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}
