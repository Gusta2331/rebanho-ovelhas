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
          _idReferencia(animal.idMae, data.animals),
          _idReferencia(animal.idPai, data.animals),
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
      horizontalAlign: HorizontalAlign.Center,
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

    _mergeRows(sheet, titleRows, rows, widths.length);
    _mergeRows(sheet, subtitleRows, rows, widths.length);
    _mergeRows(sheet, sectionRows, rows, widths.length);

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

  String _idReferencia(String? value, List<Animal> animals) {
    if (value == null || value.trim().isEmpty) {
      return 'Não informado';
    }

    final animal = animals.cast<Animal?>().firstWhere(
      (item) => item?.id == value,
      orElse: () => null,
    );

    if (animal != null) {
      return animal.brinco;
    }

    return 'Não informado';
  }

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

  Future<Uint8List> gerarManejo({
    required List<Map<String, dynamic>> registros,
    required DateTime generatedAt,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Relatório de manejo'];
    int count(String tipo) => registros.where((r) => r['tipo']?.toString() == tipo).length;
    final rows = <List<dynamic>>[
      ['RELATÓRIO DE MANEJO'],
      ['Fazenda Baixinha'],
      ['Gerado em', _manejoDateTime(generatedAt)],
      [],
      ['TOTAL', registros.length, 'PESAGENS', count('pesagem'), 'VACINAÇÕES', count('vacinacao'), 'VERMIFUGAÇÕES', count('vermifugacao')],
      ['TRATAMENTOS', count('tratamento'), 'FAMACHA', count('famacha'), 'DENTIÇÃO', count('denticao'), 'TOSQUIAS', count('tosquia')],
      ['OUTROS', count('outro')],
      [],
      ['DETALHAMENTO DOS MANEJOS POR TIPO'],
      ['Data', 'Tipo', 'Animal', 'Detalhamento', 'Dose', 'Via', 'Carência', 'Observações'],
      ..._manejoGroups(registros).entries.expand((entry) => [
        [entry.key + ' - ' + entry.value.length.toString() + ' registro(s)'],
        ['Data', 'Tipo', 'Animal', 'Detalhamento', 'Dose', 'Via', 'Carência', 'Observações'],
        ...entry.value.map((r) => [
          _manejoDate(r['data']),
          _manejoType(r['tipo']),
          _manejoAnimal(r['animais']),
          _manejoDetail(r),
          _manejoDose(r),
          _manejoText(r['via_aplicacao']),
          r['carencia_dias'] == null ? 'Não informada' : r['carencia_dias'].toString() + ' dia(s)',
          _manejoText(r['observacoes']),
        ]),
        [],
      ]),
    ];
    _writeManejoRows(sheet, rows, titleRows: {0}, subtitleRows: {1}, metadataRows: {2}, sectionRows: {8}, headerRows: {9}, summaryRows: {4, 5, 6}, widths: {0: 14, 1: 18, 2: 28, 3: 34, 4: 16, 5: 18, 6: 16, 7: 40});
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    excel.setDefaultSheet('Relatório de manejo');
    final bytes = excel.save();
    if (bytes == null) throw Exception('Não foi possível gerar o arquivo Excel.');
    return Uint8List.fromList(bytes);
  }

  Map<String, List<Map<String, dynamic>>> _manejoGroups(List<Map<String, dynamic>> registros) {
    const order = ['pesagem', 'vacinacao', 'vermifugacao', 'tratamento', 'famacha', 'denticao', 'tosquia', 'outro'];
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final tipo in order) {
      final items = registros.where((r) => r['tipo']?.toString() == tipo).toList();
      if (items.isNotEmpty) groups[_manejoType(tipo)] = items;
    }
    return groups;
  }

  void _writeManejoRows(Sheet sheet, List<List<dynamic>> rows, {Set<int> titleRows = const {}, Set<int> subtitleRows = const {}, Set<int> metadataRows = const {}, Set<int> sectionRows = const {}, Set<int> headerRows = const {}, Set<int> summaryRows = const {}, Map<int, double> widths = const {}}) {
    final title = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#367C2B'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'), fontSize: 18, bold: true, verticalAlign: VerticalAlign.Center);
    final subtitle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#EAF3E7'), fontColorHex: ExcelColor.fromHexString('#263323'), fontSize: 12, bold: true);
    final metadata = CellStyle(fontColorHex: ExcelColor.fromHexString('#5B6558'), fontSize: 10, italic: true);
    final section = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#DCEBD7'), fontColorHex: ExcelColor.fromHexString('#24551D'), fontSize: 12, bold: true);
    final header = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#367C2B'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'), fontSize: 10, bold: true, horizontalAlign: HorizontalAlign.Center, verticalAlign: VerticalAlign.Center);
    final label = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#367C2B'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'), fontSize: 9, bold: true, horizontalAlign: HorizontalAlign.Center);
    final value = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#EAF3E7'), fontColorHex: ExcelColor.fromHexString('#263323'), fontSize: 13, bold: true, horizontalAlign: HorizontalAlign.Center);
    final body = CellStyle(fontColorHex: ExcelColor.fromHexString('#263323'), verticalAlign: VerticalAlign.Center);
    final alternate = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F7F9F5'), fontColorHex: ExcelColor.fromHexString('#263323'), verticalAlign: VerticalAlign.Center);
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      for (var columnIndex = 0; columnIndex < rows[rowIndex].length; columnIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex));
        cell.value = _manejoCellValue(rows[rowIndex][columnIndex]);
        if (titleRows.contains(rowIndex)) cell.cellStyle = title;
        else if (subtitleRows.contains(rowIndex)) cell.cellStyle = subtitle;
        else if (metadataRows.contains(rowIndex)) cell.cellStyle = metadata;
        else if (sectionRows.contains(rowIndex) || (rows[rowIndex].length == 1 && rowIndex > 8)) cell.cellStyle = section;
        else if (headerRows.contains(rowIndex) || (rows[rowIndex].isNotEmpty && rows[rowIndex][0]?.toString() == 'Data')) cell.cellStyle = header;
        else if (summaryRows.contains(rowIndex)) cell.cellStyle = columnIndex.isEven ? label : value;
        else cell.cellStyle = rowIndex.isEven ? body : alternate;
      }
    }
    for (final entry in widths.entries) sheet.setColumnWidth(entry.key, entry.value);
    _mergeRows(sheet, titleRows, rows, widths.length);
    _mergeRows(sheet, subtitleRows, rows, widths.length);
    _mergeRows(sheet, sectionRows, rows, widths.length);
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      if (rows[rowIndex].length == 1 && rowIndex > 8) {
        _mergeRows(sheet, {rowIndex}, rows, widths.length);
      }
    }
    sheet.setRowHeight(0, 28); sheet.setRowHeight(1, 22); sheet.setRowHeight(4, 24); sheet.setRowHeight(5, 24); sheet.setRowHeight(6, 24); sheet.setRowHeight(8, 24); sheet.setRowHeight(9, 30);
  }

  void _mergeRows(Sheet sheet, Set<int> rowIndexes, List<List<dynamic>> rows, int columnCount) {
    if (columnCount < 2) return;
    for (final rowIndex in rowIndexes) {
      if (rowIndex < 0 || rowIndex >= rows.length) continue;
      if (rows[rowIndex].isEmpty) continue;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: columnCount - 1, rowIndex: rowIndex),
      );
    }
  }

  CellValue _manejoCellValue(dynamic value) {
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value?.toString() ?? '');
  }

  String _manejoDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? 'Não informada' : date.day.toString().padLeft(2, '0') + '/' + date.month.toString().padLeft(2, '0') + '/' + date.year.toString();
  }

  String _manejoDateTime(DateTime value) => _manejoDate(value.toIso8601String()) + ' ' + value.hour.toString().padLeft(2, '0') + ':' + value.minute.toString().padLeft(2, '0');

  String _manejoType(dynamic value) {
    switch (value?.toString()) {
      case 'vacinacao': return 'Vacinação';
      case 'vermifugacao': return 'Vermifugação';
      case 'tratamento': return 'Tratamento';
      case 'tosquia': return 'Tosquia';
      case 'pesagem': return 'Pesagem';
      case 'famacha': return 'FAMACHA';
      case 'denticao': return 'Dentição';
      default: return 'Outro';
    }
  }

  String _manejoAnimal(dynamic value) {
    if (value is! Map) return 'Animal não identificado';
    final brinco = value['brinco']?.toString().trim() ?? '';
    final nome = value['nome']?.toString().trim() ?? '';
    if (brinco.isNotEmpty && nome.isNotEmpty) return brinco + ' - ' + nome;
    if (brinco.isNotEmpty) return brinco;
    if (nome.isNotEmpty) return nome;
    return 'Animal não identificado';
  }

  String _manejoText(dynamic value) {
    final valueText = value?.toString().trim() ?? '';
    return valueText.isEmpty ? 'Não informado' : valueText;
  }

  String _manejoDose(Map<String, dynamic> r) {
    final dose = r['dose'];
    if (dose == null) return 'Não informada';
    final unidade = r['dose_unidade']?.toString().trim() ?? '';
    return unidade.isEmpty ? dose.toString() : dose.toString() + ' ' + unidade;
  }

  String _manejoDetail(Map<String, dynamic> r) {
    switch (r['tipo']?.toString()) {
      case 'pesagem': return 'Peso: ' + _manejoText(r['peso_kg']) + ' kg';
      case 'famacha': return 'Escore FAMACHA: ' + _manejoText(r['famacha_escore']);
      case 'vacinacao': return 'Vacina: ' + _manejoText(r['vacina_nome']);
      case 'vermifugacao': return 'Vermífugo: ' + _manejoText(r['vermifugo_nome']);
      case 'tratamento': return 'Medicamento: ' + _manejoText(r['medicamento_nome']);
      case 'denticao': return 'Dentição: ' + _manejoText(r['denticao']);
      case 'tosquia': return 'Tosquia: ' + _manejoText(r['outro_nome']);
      default: return _manejoText(r['outro_nome']);
    }
  }

}
