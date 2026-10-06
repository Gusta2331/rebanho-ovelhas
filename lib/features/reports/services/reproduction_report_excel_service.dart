import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/reproduction_report_data.dart';
import '../../reproduction/models/reproducao.dart';
import '../../reproduction/models/reproducao_nascimento.dart';

class ReproductionReportExcelService {
  Future<Uint8List> gerar(ReproductionReportData data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Relatório de reprodução'];

    final rows = <List<dynamic>>[
      ['RELATÓRIO DE REPRODUÇÃO'],
      ['Fazenda Baixinha'],
      ['Gerado em', _dateTime(data.generatedAt)],
      [],
      ['RESUMO'],
      ['Indicador', 'Quantidade'],
      ['Reproduções', data.total],
      ['Planejadas', data.planejadas],
      ['Cobertas', data.cobertas],
      ['Prenhes', data.prenhes],
      ['Não prenhes', data.naoPrenhes],
      ['Abortos', data.abortos],
      ['Partos realizados', data.partos],
      ['Nascimentos', data.totalNascimentos],
      ['Fêmeas nascidas', data.femeasNascidas],
      ['Machos nascidos', data.machosNascidos],
      [],
      ['DETALHAMENTO DAS REPRODUÇÕES'],
      ['Mãe','Pai','Status','Cobertura','Parto previsto','Prenhez confirmada','Parto','Nascimentos'],
      ...data.reproducoes.map((r) => [
        _animal(r.maeId, data), _animal(r.paiId, data), _status(r.status),
        _date(r.dataCobertura), _date(r.dataPrevisaoParto),
        _date(r.dataConfirmacaoPrenhez), _date(r.dataParto),
        (data.nascimentosPorReproducao[r.id] ?? const []).length,
      ]),
      [],
      ['NASCIMENTOS'],
      ['Mãe', 'Brinco', 'Sexo', 'Data de nascimento'],
      ...data.reproducoes.expand((r) =>
        (data.nascimentosPorReproducao[r.id] ?? const []).map((n) => [
          _animal(r.maeId, data),
          _animal(n.animalId, data),
          n.sexo == SexoNascimento.femea ? 'Fêmea' : 'Macho',
          _date(n.dataNascimento),
        ])),
    ];

    final titleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 18, bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final subtitleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#EAF3E7'),
      fontColorHex: ExcelColor.fromHexString('#263323'),
      fontSize: 12, bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final metadataStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#5B6558'),
      fontSize: 10, italic: true,
      verticalAlign: VerticalAlign.Center,
    );
    final sectionStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#DCEBD7'),
      fontColorHex: ExcelColor.fromHexString('#24551D'),
      fontSize: 13, bold: true,
      verticalAlign: VerticalAlign.Center,
    );
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 10, bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final bodyStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#263323'),
      verticalAlign: VerticalAlign.Center,
    );
    final alternateStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F7F9F5'),
      fontColorHex: ExcelColor.fromHexString('#263323'),
      verticalAlign: VerticalAlign.Center,
    );
    final numberStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#263323'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: columnIndex, rowIndex: rowIndex));
        cell.value = _cellValue(row[columnIndex]);

        if (rowIndex == 0) {
          cell.cellStyle = titleStyle;
        } else if (rowIndex == 1) {
          cell.cellStyle = subtitleStyle;
        } else if (rowIndex == 2) {
          cell.cellStyle = metadataStyle;
        } else if (rowIndex == 4 || rowIndex == 17 || rowIndex == 23) {
          cell.cellStyle = sectionStyle;
        } else if (rowIndex == 5 || rowIndex == 18 || rowIndex == 24) {
          cell.cellStyle = headerStyle;
        } else if (rowIndex >= 6 && rowIndex <= 15) {
          cell.cellStyle = columnIndex == 1 ? numberStyle : bodyStyle;
        } else {
          cell.cellStyle = rowIndex.isEven ? bodyStyle : alternateStyle;
        }
      }
    }

    final widths = <int, double>{
      0: 27, 1: 27, 2: 19, 3: 18,
      4: 20, 5: 23, 6: 18, 7: 15,
    };
    for (final entry in widths.entries) {
      sheet.setColumnWidth(entry.key, entry.value);
    }

    for (final rowIndex in [0, 1, 4, 17, 23]) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
      );
    }

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 23);
    sheet.setRowHeight(2, 20);
    sheet.setRowHeight(4, 27);
    sheet.setRowHeight(5, 30);
    sheet.setRowHeight(17, 27);
    sheet.setRowHeight(18, 34);
    sheet.setRowHeight(23, 27);
    sheet.setRowHeight(24, 30);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    excel.setDefaultSheet('Relatório de reprodução');

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  CellValue _cellValue(dynamic value) {
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value?.toString() ?? '');
  }

  String _animal(String? id, ReproductionReportData data) {
    if (id == null || id.trim().isEmpty) return 'Não informado';
    final animal = data.animaisPorId[id];
    if (animal == null) return 'Não informado';
    final nome = animal.nome?.trim();
    if (nome == null || nome.isEmpty) return animal.brinco;
    return animal.brinco + ' • ' + nome;
  }

  String _status(StatusReproducao status) => switch (status) {
    StatusReproducao.planejada => 'Planejada',
    StatusReproducao.coberta => 'Coberta',
    StatusReproducao.prenhe => 'Prenhe',
    StatusReproducao.naoPrenhe => 'Não prenhe',
    StatusReproducao.abortou => 'Abortou',
    StatusReproducao.partoRealizado => 'Parto realizado',
    StatusReproducao.encerrada => 'Encerrada',
  };

  String _date(DateTime? date) {
    if (date == null) return 'Não informada';
    return date.day.toString().padLeft(2, '0') + '/' +
        date.month.toString().padLeft(2, '0') + '/' + date.year.toString();
  }

  String _dateTime(DateTime date) {
    return _date(date) + ' ' +
        date.hour.toString().padLeft(2, '0') + ':' +
        date.minute.toString().padLeft(2, '0');
  }
}
