import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../reproduction/models/reproducao.dart';
import '../../reproduction/models/reproducao_nascimento.dart';
import '../models/reproduction_report_data.dart';

class ReproductionReportPdfService {
  Future<Uint8List> gerar(ReproductionReportData data) async {
    final doc = pw.Document();
    final green = PdfColor.fromHex('#367C2B');
    final light = PdfColor.fromHex('#EAF3E7');
    final muted = PdfColor.fromHex('#667060');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28,30,28,34),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Fazenda Baixinha • OviGestão', style: pw.TextStyle(fontSize:8,color:muted)),
          pw.Text('Página ' + c.pageNumber.toString() + ' de ' + c.pagesCount.toString(), style: pw.TextStyle(fontSize:8,color:muted)),
        ],
      ),
      build: (c) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(color:green,borderRadius:pw.BorderRadius.circular(12)),
          child: pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
            pw.Text('RELATÓRIO DE REPRODUÇÃO',style:pw.TextStyle(color:PdfColors.white,fontSize:20,fontWeight:pw.FontWeight.bold)),
            pw.SizedBox(height:5),
            pw.Text('Fazenda Baixinha • gerado em ' + _dateTime(data.generatedAt),style:pw.TextStyle(color:PdfColors.white,fontSize:9)),
          ]),
        ),
        pw.SizedBox(height:16),
        pw.Wrap(spacing:8,runSpacing:8,children:[
          _card('Reproduções',data.total,green,light),
          _card('Planejadas',data.planejadas,green,light),
          _card('Cobertas',data.cobertas,green,light),
          _card('Prenhes',data.prenhes,green,light),
          _card('Partos',data.partos,green,light),
          _card('Nascimentos',data.totalNascimentos,green,light),
          _card('Fêmeas',data.femeasNascidas,green,light),
          _card('Machos',data.machosNascidos,green,light),
        ]),
        pw.SizedBox(height:20),
        _title('Reproduções',green),
        pw.SizedBox(height:8),
        pw.Table(
          border:pw.TableBorder.all(color:PdfColors.grey300,width:.5),
          children:[
            _header(['Mãe','Pai','Status','Cobertura','Parto previsto','Parto'],green),
            ...data.reproducoes.map((r)=>pw.TableRow(children:[
              _cell(_animal(r.maeId,data)),_cell(_animal(r.paiId,data)),_cell(_status(r.status)),
              _cell(_date(r.dataCobertura)),_cell(_date(r.dataPrevisaoParto)),_cell(_date(r.dataParto)),
            ])),
          ],
        ),
        pw.SizedBox(height:20),
        _title('Nascimentos',green),
        pw.SizedBox(height:8),
        pw.Table(
          border:pw.TableBorder.all(color:PdfColors.grey300,width:.5),
          children:[
            _header(['Mãe','Brinco','Sexo','Data de nascimento'],green),
            ...data.reproducoes.expand((r)=>(data.nascimentosPorReproducao[r.id]??const[]).map((n)=>pw.TableRow(children:[
              _cell(_animal(r.maeId,data)),_cell(_animal(n.animalId,data)),
              _cell(n.sexo==SexoNascimento.femea?'Fêmea':'Macho'),_cell(_date(n.dataNascimento)),
            ]))),
          ],
        ),
      ],
    ));
    return doc.save();
  }

  pw.Widget _title(String text,PdfColor color)=>pw.Text(text,style:pw.TextStyle(color:color,fontSize:13,fontWeight:pw.FontWeight.bold));
  pw.Widget _card(String label,int value,PdfColor green,PdfColor bg) {
    return pw.Container(
      width: 88,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value.toString(), style: pw.TextStyle(color: green, fontSize: 17, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
  pw.TableRow _header(List<String> values,PdfColor green)=>pw.TableRow(decoration:pw.BoxDecoration(color:green),children:values.map((v)=>pw.Padding(padding:const pw.EdgeInsets.all(6),child:pw.Text(v,style:pw.TextStyle(color:PdfColors.white,fontSize:7.5,fontWeight:pw.FontWeight.bold)))).toList());
  pw.Widget _cell(String value)=>pw.Padding(padding:const pw.EdgeInsets.all(5),child:pw.Text(value,style:const pw.TextStyle(fontSize:7)));
  String _animal(String? id,ReproductionReportData data){if(id==null||id.trim().isEmpty)return 'Não informado';final a=data.animaisPorId[id];if(a==null)return 'Não informado';final n=a.nome?.trim();return n==null||n.isEmpty?a.brinco:a.brinco+' • '+n;}
  String _status(StatusReproducao s)=>switch(s){StatusReproducao.planejada=>'Planejada',StatusReproducao.coberta=>'Coberta',StatusReproducao.prenhe=>'Prenhe',StatusReproducao.naoPrenhe=>'Não prenhe',StatusReproducao.abortou=>'Abortou',StatusReproducao.partoRealizado=>'Parto realizado',StatusReproducao.encerrada=>'Encerrada'};
  String _date(DateTime? d)=>d==null?'Não informada':d.day.toString().padLeft(2,'0')+'/'+d.month.toString().padLeft(2,'0')+'/'+d.year.toString();
  String _dateTime(DateTime d)=>_date(d)+' '+d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');
}
