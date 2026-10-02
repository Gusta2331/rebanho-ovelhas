import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/report_data.dart';
import '../../animals/models/animal.dart';

class ReportExcelService {
  Future<Uint8List> gerarRebanho(ReportData data) async {
    final excel = Excel.createExcel();

    final resumo = excel['Resumo'];
    _writeRows(
      resumo,
      [
        ['RELATÓRIO DO REBANHO'],
        ['Gerado em', _dateTime(data.generatedAt)],
        [],
        ['Indicador', 'Quantidade'],
        ['Total', data.total],
        ['Ativos', data.ativos],
        ['Vendidos', data.vendidos],
        ['Mortos', data.mortos],
        ['Descartados', data.descartados],
        ['Fêmeas', data.femeas],
        ['Machos', data.machos],
      ],
      titleRows: {0},
      headerRows: {3},
      accentRows: {4},
      widths: {0: 24, 1: 18},
    );

    final racas = excel['Por raça'];
    _writeRows(
      racas,
      [
        ['RAÇA', 'QUANTIDADE', '%'],
        ...data.porRaca.entries.map((e) => [
              e.key,
              e.value,
              data.percentualRaca(e.value) / 100,
            ]),
      ],
      headerRows: {0},
      widths: {0: 30, 1: 16, 2: 12},
    );

    final animais = excel['Animais'];
    _writeRows(
      animais,
      [
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
          ],
        ),
      ],
      headerRows: {0},
      widths: {
        0: 12,
        1: 24,
        2: 12,
        3: 22,
        4: 15,
        5: 15,
        6: 14,
        7: 15,
        8: 15,
        9: 18,
        10: 18,
      },
    );

    if (excel.tables.containsKey('Sheet1') && excel.tables.length > 1) {
      excel.delete('Sheet1');
      excel.setDefaultSheet('Resumo');
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }

    return Uint8List.fromList(bytes);
  }

  void _writeRows(
    Sheet sheet,
    List<List<dynamic>> rows, {
    Set<int> titleRows = const {},
    Set<int> headerRows = const {},
    Set<int> accentRows = const {},
    Map<int, double> widths = const {},
  }) {
    final titleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 16,
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

    final accentStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#EAF3E7'),
      fontColorHex: ExcelColor.fromHexString('#263323'),
      bold: true,
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

        final value = row[columnIndex];
        cell.value = _cellValue(value);

        if (titleRows.contains(rowIndex)) {
          cell.cellStyle = titleStyle;
        } else if (headerRows.contains(rowIndex)) {
          cell.cellStyle = headerStyle;
        } else if (accentRows.contains(rowIndex)) {
          cell.cellStyle = accentStyle;
        } else {
          cell.cellStyle =
              rowIndex.isEven ? bodyStyle : alternateStyle;
        }
      }
    }

    for (final entry in widths.entries) {
      sheet.setColumnWidth(entry.key, entry.value);
    }

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

  String _origem(OrigemAnimal origem) =>
      origem == OrigemAnimal.nascido ? 'Nascido' : 'Comprado';
}
