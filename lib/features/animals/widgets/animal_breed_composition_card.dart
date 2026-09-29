import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/composicao_racial.dart';

class AnimalBreedCompositionCard extends StatelessWidget {
  final List<ComposicaoRacial> composicoes;
  final bool carregando;
  final String? erro;
  final VoidCallback? onRetry;

  const AnimalBreedCompositionCard({super.key, required this.composicoes, this.carregando=false, this.erro, this.onRetry});

  String _percentual(double valor) => valor.roundToDouble() == valor
      ? valor.toStringAsFixed(0) + '%'
      : valor.toStringAsFixed(1).replaceAll('.', ',') + '%';

  @override
  Widget build(BuildContext context) {
    return _buildCard();
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE0E5DC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width:42,height:42,decoration:BoxDecoration(color:AppTheme.primaryColor.withValues(alpha:0.10),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.biotech_outlined,color:AppTheme.primaryColor)),
          const SizedBox(width:12),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Composição racial',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:AppTheme.textColor)),
            SizedBox(height:3),
            Text('Calculada a partir da filiação cadastrada.',style:TextStyle(fontSize:13,color:Colors.black54)),
          ])),
        ]),
        const SizedBox(height:14),
        if (carregando) const Center(child:Padding(padding:EdgeInsets.all(12),child:CircularProgressIndicator()))
        else if (erro != null) ListTile(contentPadding:EdgeInsets.zero,title:Text(erro!),trailing:IconButton(onPressed:onRetry,icon:const Icon(Icons.refresh)))
        else if (composicoes.isEmpty) const Text('Ainda não foi possível calcular a composição racial.')
        else ...[
          ...composicoes.map((item)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[
          Expanded(child:Text(item.racaNome,style:const TextStyle(fontWeight:FontWeight.w600))),
          Text(_percentual(item.percentual),style:const TextStyle(fontWeight:FontWeight.bold,color:AppTheme.primaryColor)),
        ])),
          if (composicoes.fold<double>(0, (s, item) => s + item.percentual) < 99.9)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('Parte da composição é desconhecida porque falta a filiação completa.', style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
        ],
      ]),
    );
  }
}
