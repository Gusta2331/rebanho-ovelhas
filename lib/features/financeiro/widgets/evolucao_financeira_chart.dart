import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class EvolucaoFinanceiraChart extends StatelessWidget {
  final List<Map<String, dynamic>> registros;

  const EvolucaoFinanceiraChart({super.key, required this.registros});

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final meses = List<DateTime>.generate(
      6,
      (i) => DateTime(hoje.year, hoje.month - (5 - i), 1),
    );
    final receitas = List<double>.filled(6, 0);
    final despesas = List<double>.filled(6, 0);

    for (final registro in registros) {
      final data = DateTime.tryParse(registro['data']?.toString() ?? '');
      if (data == null) continue;
      final indice = meses.indexWhere(
        (mes) => mes.year == data.year && mes.month == data.month,
      );
      if (indice < 0) continue;
      final valorBruto = registro['valor'];
      final valor = valorBruto is num
          ? valorBruto.toDouble()
          : double.tryParse(valorBruto?.toString() ?? '') ?? 0;
      if (registro['tipo'] == 'receita') {
        receitas[indice] += valor;
      } else {
        despesas[indice] += valor;
      }
    }

    final maiorValor = [...receitas, ...despesas]
        .fold<double>(0, (maior, valor) => valor > maior ? valor : maior);
    final maxY = maiorValor <= 0 ? 100.0 : maiorValor * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Receitas x despesas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Últimos 6 meses',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  barTouchData: BarTouchData(enabled: true),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: _tituloEixo,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final indice = value.toInt();
                          if (indice < 0 || indice >= meses.length) {
                            return const SizedBox.shrink();
                          }
                          const nomes = [
                            'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                            'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
                          ];
                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              nomes[meses[indice].month - 1],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List<BarChartGroupData>.generate(6, (i) {
                    return BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: receitas[i],
                          color: AppTheme.primaryColor,
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        BarChartRodData(
                          toY: despesas[i],
                          color: const Color(0xFFE58B42),
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendaFinanceira(cor: AppTheme.primaryColor, texto: 'Receitas'),
                _LegendaFinanceira(cor: Color(0xFFE58B42), texto: 'Despesas'),
              ],
            ),
            if (registros.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Ainda não há lançamentos para comparar.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _tituloEixo(double value, TitleMeta meta) {
    String texto;
    if (value >= 1000) {
      texto = '${(value / 1000).toStringAsFixed(0)} mil';
    } else {
      texto = value.toStringAsFixed(0);
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(texto, style: const TextStyle(fontSize: 9)),
    );
  }
}

class _LegendaFinanceira extends StatelessWidget {
  final Color cor;
  final String texto;

  const _LegendaFinanceira({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(texto, style: const TextStyle(fontSize: 12)),
    ],
  );
}
