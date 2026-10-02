import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/report_data.dart';
import '../../animals/models/animal.dart';

class ReportExcelService {
  Future<Uint8List> gerarRebanho(ReportData data) async {
    final excel = Excel.createExcel();

    final resumo = excel['Resumo'];
    _writeRows(resumo, [
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
    ]);

    final racas = excel['Por raça'];
    _writeRows(racas, [
      ['RAÇA', 'QUANTIDADE'],
      ...data.porRaca.entries.map((e) => [e.key, e.value]),
    ]);

    final animais = excel['Animais'];
    _writeRows(animais, [
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
      ...data.animals.map((animal) => [
            animal.brinco,
            animal.nome ?? '',
            _sexo(animal.sexo),
            animal.raca,
            _date(animal.dataNascimento),
            _status(animal.status),
            _origem(animal.origem),
            _date(animal.dataEntrada),
            _date(animal.dataSaida),
            animal.idMae ?? '',
            animal.idPai ?? '',
          ]),
    ]);

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

  void _writeRows(Sheet sheet, List<List<dynamic>> rows) {
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      for (var columnIndex = 0; columnIndex < rows[rowIndex].length; columnIndex++) {
        final value = rows[rowIndex][columnIndex];
        sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        )).value = _cellValue(value);
      }
    }
  }

  CellValue _cellValue(dynamic value) {
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value?.toString() ?? '');
  }

  String _date(DateTime? value) => value == null
      ? ''
      : value.day.toString().padLeft(2, '0') + '/' +
          value.month.toString().padLeft(2, '0') + '/' +
          value.year.toString();

  String _dateTime(DateTime value) =>
      _date(value) + ' ' +
      value.hour.toString().padLeft(2, '0') + ':' +
      value.minute.toString().padLeft(2, '0');

  String _sexo(SexoAnimal sexo) => sexo == SexoAnimal.femea ? 'Fêmea' : 'Macho';

  String _status(StatusAnimal status) => switch (status) {
        StatusAnimal.ativo => 'Ativo',
        StatusAnimal.vendido => 'Vendido',
        StatusAnimal.morto => 'Morto',
        StatusAnimal.descartado => 'Descartado',
      };

  String _origem(OrigemAnimal origem) =>
      origem == OrigemAnimal.nascido ? 'Nascido' : 'Comprado';
}
