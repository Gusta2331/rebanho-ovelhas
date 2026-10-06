import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/reproduction_report_data.dart';
import '../../reproduction/models/reproducao.dart';
import '../../reproduction/models/reproducao_nascimento.dart';

class ReproductionReportExcelService {
  Future<Uint8List> gerar(ReproductionReportData data) async {
    final excel=Excel.createExcel();
    final sheet=excel['Relatório de reprodução'];
    final rows=<List<dynamic>>[
      ['RELATÓRIO DE REPRODUÇÃO'],['Fazenda Baixinha'],['Gerado em',_dateTime(data.generatedAt)],[],
      ['REPRODUÇÕES',data.total,'PRENHES',data.prenhes,'PARTOS',data.partos,'NASCIMENTOS',data.totalNascimentos],
      ['PLANEJADAS',data.planejadas,'COBERTAS',data.cobertas,'NÃO PRENHES',data.naoPrenhes,'ABORTOS',data.abortos],[],
      ['DETALHAMENTO DAS REPRODUÇÕES'],['Mãe','Pai','Status','Cobertura','Parto previsto','Prenhez confirmada','Parto','Nascimentos'],
      ...data.reproducoes.map((r)=>[_animal(r.maeId,data),_animal(r.paiId,data),_status(r.status),_date(r.dataCobertura),_date(r.dataPrevisaoParto),_date(r.dataConfirmacaoPrenhez),_date(r.dataParto),(data.nascimentosPorReproducao[r.id]??const[]).length]),
      [],['NASCIMENTOS'],['Mãe','Brinco','Sexo','Data de nascimento'],
      ...data.reproducoes.expand((r)=>(data.nascimentosPorReproducao[r.id]??const[]).map((n)=>[_animal(r.maeId,data),_animal(n.animalId,data),n.sexo==SexoNascimento.femea?'Fêmea':'Macho',_date(n.dataNascimento)])),
    ];
    final title=CellStyle(backgroundColorHex:ExcelColor.fromHexString('#367C2B'),fontColorHex:ExcelColor.fromHexString('#FFFFFF'),fontSize:18,bold:true,horizontalAlign:HorizontalAlign.Center,verticalAlign:VerticalAlign.Center);
    final sub=CellStyle(backgroundColorHex:ExcelColor.fromHexString('#EAF3E7'),fontColorHex:ExcelColor.fromHexString('#263323'),fontSize:12,bold:true);
    final header=CellStyle(backgroundColorHex:ExcelColor.fromHexString('#367C2B'),fontColorHex:ExcelColor.fromHexString('#FFFFFF'),fontSize:10,bold:true,horizontalAlign:HorizontalAlign.Center,verticalAlign:VerticalAlign.Center);
    final section=CellStyle(backgroundColorHex:ExcelColor.fromHexString('#DCEBD7'),fontColorHex:ExcelColor.fromHexString('#24551D'),fontSize:12,bold:true);
    final body=CellStyle(fontColorHex:ExcelColor.fromHexString('#263323'),verticalAlign:VerticalAlign.Center);
    final alt=CellStyle(backgroundColorHex:ExcelColor.fromHexString('#F7F9F5'),fontColorHex:ExcelColor.fromHexString('#263323'),verticalAlign:VerticalAlign.Center);
    final label=CellStyle(backgroundColorHex:ExcelColor.fromHexString('#367C2B'),fontColorHex:ExcelColor.fromHexString('#FFFFFF'),fontSize:9,bold:true,horizontalAlign:HorizontalAlign.Center);
    final value=CellStyle(backgroundColorHex:ExcelColor.fromHexString('#EAF3E7'),fontColorHex:ExcelColor.fromHexString('#263323'),fontSize:13,bold:true,horizontalAlign:HorizontalAlign.Center);
    for(var r=0;r<rows.length;r++){for(var c=0;c<rows[r].length;c++){final cell=sheet.cell(CellIndex.indexByColumnRow(columnIndex:c,rowIndex:r));cell.value=_cellValue(rows[r][c]);if(r==0)cell.cellStyle=title;else if(r==1)cell.cellStyle=sub;else if(r==7||r==11)cell.cellStyle=section;else if(r==8||r==12)cell.cellStyle=header;else if(r==4||r==5)cell.cellStyle=c.isEven?label:value;else cell.cellStyle=r.isEven?body:alt;}}
    const widths={0:28.0,1:28.0,2:18.0,3:18.0,4:18.0,5:20.0,6:18.0,7:14.0};
    for(final e in widths.entries){sheet.setColumnWidth(e.key,e.value);}
    for(final r in [0,1,7,11]){sheet.merge(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:r),CellIndex.indexByColumnRow(columnIndex:7,rowIndex:r));}
    sheet.setRowHeight(0,28);sheet.setRowHeight(1,22);sheet.setRowHeight(4,24);sheet.setRowHeight(5,24);sheet.setRowHeight(7,24);sheet.setRowHeight(8,30);sheet.setRowHeight(11,24);sheet.setRowHeight(12,30);
    if(excel.sheets.containsKey('Sheet1'))excel.delete('Sheet1');excel.setDefaultSheet('Relatório de reprodução');
    final bytes=excel.save();if(bytes==null)throw Exception('Não foi possível gerar o arquivo Excel.');return Uint8List.fromList(bytes);
  }
  CellValue _cellValue(dynamic v){if(v is int)return IntCellValue(v);if(v is double)return DoubleCellValue(v);if(v is bool)return BoolCellValue(v);return TextCellValue(v?.toString()??'');}
  String _animal(String? id,ReproductionReportData data){if(id==null||id.trim().isEmpty)return 'Não informado';final a=data.animaisPorId[id];if(a==null)return 'Não informado';final n=a.nome?.trim();return n==null||n.isEmpty?a.brinco:a.brinco+' - '+n;}
  String _status(StatusReproducao s)=>switch(s){StatusReproducao.planejada=>'Planejada',StatusReproducao.coberta=>'Coberta',StatusReproducao.prenhe=>'Prenhe',StatusReproducao.naoPrenhe=>'Não prenhe',StatusReproducao.abortou=>'Abortou',StatusReproducao.partoRealizado=>'Parto realizado',StatusReproducao.encerrada=>'Encerrada'};
  String _date(DateTime? d)=>d==null?'Não informada':d.day.toString().padLeft(2,'0')+'/'+d.month.toString().padLeft(2,'0')+'/'+d.year.toString();
  String _dateTime(DateTime d)=>_date(d)+' '+d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');
}
