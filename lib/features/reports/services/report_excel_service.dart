import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../animals/models/animal.dart';
import '../models/report_data.dart';

class ReportExcelService {
  Future<Uint8List> gerarRebanho(ReportData data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Relatório do rebanho'];

    _writeReport(sheet, data);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    excel.setDefaultSheet('Relatório do rebanho');

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }

    return Uint8List.fromList(bytes);
  }

  void _writeReport(Sheet sheet, ReportData data) {
    final rows = <List<dynamic>>[
      ['RELATÓRIO DO REBANHO'],
      ['Fazenda Baixinha'],
      ['Gerado em', _dateTime(data.generatedAt)],
      [],
      [
        'TOTAL',
        data.total,
        'ATIVOS',
        data.ativos,
        'VENDIDOS',
        data.vendidos,
        'MORTOS',
        data.mortos,
        'DESCARTADOS',
        data.descartados,
      ],
      [
        'FÊMEAS',
        data.femeas,
        'MACHOS',
        data.machos,
        'RAÇAS',
        data.porRaca.length,
        '',
        '',
        '',
        '',
      ],
      [],
      ['DETALHAMENTO DOS ANIMAIS'],
      [
        'Brinco',
        'Nome',
        'Sexo',
        'Raça',
        'Nascimento',
        'Status',
        'Origem',
        'Entrada',
        'Saída',
        'Mãe',
        'Pai',
        'Composição racial',
      ],
      ...data.animals.map(
        (animal) => [
          animal.brinco,
          _nome(animal.nome),
          _sexo(animal.sexo),
          _raca(animal.raca),
          _date(animal.dataNascimento),
          _status(animal.status),
          _origem(animal.origem),
          _date(animal.dataEntrada),
          _date(animal.dataSaida),
          _idReferencia(animal.idMae),
          _idReferencia(animal.idPai),
          _composicao(data.composicoesPorAnimal[animal.id]),
        ],
      ),
    ];

    _writeRows(
      sheet,
      rows,
      titleRows: {0},
      subtitleRows: {1},
      metadataRows: {2},
      sectionRows: {7},
      headerRows: {8},
      summaryRows: {4, 5},
      widths: {
        0: 12,
        1: 25,
        2: 12,
        3: 22,
        4: 15,
        5: 15,
        6: 14,
        7: 15,
        8: 15,
        9: 18,
        10: 18,
        11: 42,
      },
    );
  }

  void _writeRows(
    Sheet sheet,
    List<List<dynamic>> rows, {
    Set<int> titleRows = const {},
    Set<int> subtitleRows = const {},
    Set<int> metadataRows = const {},
    Set<int> sectionRows = const {},
    Set<int> headerRows = const {},
    Set<int> summaryRows = const {},
    Map<int, double> widths = const {},
  }) {
    final titleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 18,
      bold: true,
      verticalAlign: VerticalAlign.Center,
    );

    final subtitleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#EAF3E7'),
      fontColorHex: ExcelColor.fromHexString('#263323'),
      fontSize: 12,
      bold: true,
      verticalAlign: VerticalAlign.Center,
    );

    final metadataStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#5B6558'),
      fontSize: 10,
      italic: true,
      verticalAlign: VerticalAlign.Center,
    );

    final sectionStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#DCEBD7'),
      fontColorHex: ExcelColor.fromHexString('#24551D'),
      fontSize: 12,
      bold: true,
      verticalAlign: VerticalAlign.Center,
    );

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 10,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final summaryLabelStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 9,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final summaryValueStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#EAF3E7'),
      fontColorHex: ExcelColor.fromHexString('#263323'),
      fontSize: 13,
      bold: true,
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

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];

      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: columnIndex,
            rowIndex: rowIndex,
          ),
        );

        cell.value = _cellValue(row[columnIndex]);

        if (titleRows.contains(rowIndex)) {
          cell.cellStyle = titleStyle;
        } else if (subtitleRows.contains(rowIndex)) {
          cell.cellStyle = subtitleStyle;
        } else if (metadataRows.contains(rowIndex)) {
          cell.cellStyle = metadataStyle;
        } else if (sectionRows.contains(rowIndex)) {
          cell.cellStyle = sectionStyle;
        } else if (headerRows.contains(rowIndex)) {
          cell.cellStyle = headerStyle;
        } else if (summaryRows.contains(rowIndex)) {
          cell.cellStyle = columnIndex.isEven
              ? summaryLabelStyle
              : summaryValueStyle;
        } else {
          cell.cellStyle =
              rowIndex.isEven ? bodyStyle : alternateStyle;
        }
      }
    }

    for (final entry in widths.entries) {
      sheet.setColumnWidth(entry.key, entry.value);
    }

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 22);
    sheet.setRowHeight(4, 24);
    sheet.setRowHeight(5, 24);
    sheet.setRowHeight(7, 24);
    sheet.setRowHeight(8, 30);
  }

  CellValue _cellValue(dynamic value) {
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value?.toString() ?? '');
  }

  String _nome(String? value) =>
      value == null || value.trim().isEmpty ? 'Não informado' : value.trim();

  String _raca(String value) =>
      value.trim().isEmpty ? 'Não informada' : value.trim();

  String _idReferencia(String? value) =>
      value == null || value.trim().isEmpty ? 'Não informado' : value.trim();

  String _date(DateTime? value) => value == null
      ? 'Não informada'
      : value.day.toString().padLeft(2, '0') +
          '/' +
          value.month.toString().padLeft(2, '0') +
          '/' +
          value.year.toString();

  String _dateTime(DateTime value) =>
      _date(value) +
      ' ' +
      value.hour.toString().padLeft(2, '0') +
      ':' +
      value.minute.toString().padLeft(2, '0');

  String _sexo(SexoAnimal sexo) =>
      sexo == SexoAnimal.femea ? 'Fêmea' : 'Macho';

  String _status(StatusAnimal status) => switch (status) {
        StatusAnimal.ativo => 'Ativo',
        StatusAnimal.vendido => 'Vendido',
        StatusAnimal.morto => 'Morto',
        StatusAnimal.descartado => 'Descartado',
      };

  String _composicao(List<dynamic>? composicoes) {
    if (composicoes == null || composicoes.isEmpty) return 'Não informada';

    return composicoes.map((item) {
      final nome = item.racaNome.toString();
      final percentual = item.percentual as double;
      final valor = percentual.roundToDouble() == percentual
          ? percentual.toStringAsFixed(0)
          : percentual.toStringAsFixed(1);

      return '$valor% $nome';
    }).join(' + ');
  }

  String _origem(OrigemAnimal origem) =>
      origem == OrigemAnimal.nascido ? 'Nascido' : 'Comprado';
}
