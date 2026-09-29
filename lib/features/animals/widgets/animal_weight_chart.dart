import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../manejo/models/manejo.dart';

class AnimalWeightChart extends StatelessWidget {
  final List<Manejo> registros;
  const AnimalWeightChart({super.key, required this.registros});

  String _data(DateTime data) => data.day.toString().padLeft(2, '0') + '/' + data.month.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final pesos = registros.where((m) => m.pesoKg != null && m.pesoKg! > 0).toList()..sort((a, b) => a.data.compareTo(b.data));
    if (pesos.length < 2) return const SizedBox.shrink();

    final valores = pesos.map((m) => m.pesoKg!).toList();
    final minPeso = valores.reduce((a, b) => a < b ? a : b);
    final maxPeso = valores.reduce((a, b) => a > b ? a : b);
    final margem = ((maxPeso - minPeso) * 0.20).clamp(1.0, 10.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE0E5DC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width:42,height:42,decoration:BoxDecoration(color:AppTheme.primaryColor.withValues(alpha:0.10),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.show_chart_rounded,color:AppTheme.primaryColor)),
          const SizedBox(width:12),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Evolução do peso',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:AppTheme.textColor)),
            SizedBox(height:3),
            Text('Histórico das pesagens registradas.',style:TextStyle(fontSize:13,color:Colors.black54)),
          ])),
        ]),
        const SizedBox(height:20),
        SizedBox(height:230,child:LineChart(LineChartData(
          minY:(minPeso-margem).clamp(0,double.infinity),
          maxY:maxPeso+margem,
          gridData:FlGridData(show:true,drawVerticalLine:false),
          borderData:FlBorderData(show:false),
          titlesData:FlTitlesData(
            topTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
            rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
            leftTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:42,getTitlesWidget:(value,meta)=>Text(value.toStringAsFixed(0)+' kg',style:const TextStyle(fontSize:10,color:Colors.black54)))),
            bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:28,interval:pesos.length>6?(pesos.length/5).ceilToDouble():1,getTitlesWidget:(value,meta){
              final index=value.round();
              if(index<0||index>=pesos.length)return const SizedBox.shrink();
              return Padding(padding:const EdgeInsets.only(top:8),child:Text(_data(pesos[index].data),style:const TextStyle(fontSize:10,color:Colors.black54)));
            })),
          ),
          lineTouchData:LineTouchData(touchTooltipData:LineTouchTooltipData(getTooltipItems:(spots)=>spots.map((spot){
            final peso=valores[spot.x.round()];
            return LineTooltipItem(peso.toStringAsFixed(1).replaceAll('.',',')+' kg',const TextStyle(fontWeight:FontWeight.bold,color:Colors.white));
          }).toList())),
          lineBarsData:[LineChartBarData(
            spots:[for(var i=0;i<valores.length;i++)FlSpot(i.toDouble(),valores[i])],
            isCurved:true,barWidth:3,color:AppTheme.primaryColor,
            dotData:const FlDotData(show:true),
            belowBarData:BarAreaData(show:true,color:AppTheme.primaryColor.withValues(alpha:0.10)),
          )],
        ))),
        const SizedBox(height:16),
        Row(children:[
          Expanded(child:_metric('Primeiro',valores.first)),
          Expanded(child:_metric('Atual',valores.last)),
          Expanded(child:_metric('Máximo',maxPeso)),
        ]),
      ]),
    );
  }

  Widget _metric(String titulo,double valor)=>Column(children:[
    Text(titulo,style:const TextStyle(fontSize:12,color:Colors.black54)),
    const SizedBox(height:3),
    Text(valor.toStringAsFixed(1).replaceAll('.',',')+' kg',style:const TextStyle(fontWeight:FontWeight.bold,color:AppTheme.textColor)),
  ]);
}
