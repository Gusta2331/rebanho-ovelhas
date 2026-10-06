import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/reproduction_report_data.dart';
import '../../reproduction/models/reproducao.dart';
import '../../reproduction/models/reproducao_nascimento.dart';

class ReproductionReportExcelService {
  Future<Uint8List> gerar(ReproductionReportData data) async {
    final excel = Excel.createExcel();

    final resumo = excel['Resumo'];
    final reproducoes = excel['Reproduções'];
    final nascimentos = excel['Nascimentos'];

    _buildResumo(resumo, data);
    _buildReproducoes(reproducoes, data);
    _buildNascimentos(nascimentos, data);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    excel.setDefaultSheet('Resumo');

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }

    return Uint8List.fromList(bytes);
  }

  void _buildResumo(Sheet sheet, ReproductionReportData data) {
    final title = _titleStyle();
    final subtitle = _subtitleStyle();
    final section = _sectionStyle();
    final label = _labelStyle();
    final value = _valueStyle();
    final muted = _mutedStyle();

    final rows = <List<dynamic>>[
      ['RELATÓRIO DE REPRODUÇÃO'],
      ['Fazenda Baixinha'],
      ['Gerado em', _dateTime(data.generatedAt)],
      [],
      ['RESUMO DO REBANHO REPRODUTIVO'],
      ['Indicador', 'Quantidade'],
      ['Total de reproduções', data.total],
      ['Planejadas', data.planejadas],
      ['Cobertas', data.cobertas],
      ['Prenhes', data.prenhes],
      ['Não prenhes', data.naoPrenhes],
      ['Abortos', data.abortos],
      ['Partos realizados', data.partos],
      ['Nascimentos', data.totalNascimentos],
      ['Fêmeas nascidas', data.femeasNascidas],
      ['Machos nascidos', data.machosNascidos],
    ];

    for (var row = 0; row < rows.length; row++) {
      for (var col = 0; col < rows[row].length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = _cellValue(rows[row][col]);

        if (row == 0) {
          cell.cellStyle = title;
        } else if (row == 1) {
          cell.cellStyle = subtitle;
        } else if (row == 2) {
          cell.cellStyle = muted;
        } else if (row == 4) {
          cell.cellStyle = section;
        } else if (row == 5) {
          cell.cellStyle = _headerStyle();
        } else if (col == 0) {
          cell.cellStyle = label;
        } else {
          cell.cellStyle = value;
        }
      }
    }

    _merge(sheet, 0, 5, 0);
    _merge(sheet, 0, 5, 1);
    _merge(sheet, 0, 5, 4);

    sheet.setColumnWidth(0, 34);
    sheet.setColumnWidth(1, 18);

    sheet.setRowHeight(0, 36);
    sheet.setRowHeight(1, 24);
    sheet.setRowHeight(2, 20);
    sheet.setRowHeight(4, 28);
    sheet.setRowHeight(5, 30);

  }

  void _buildReproducoes(Sheet sheet, ReproductionReportData data) {
    final rows = <List<dynamic>>[
      ['DETALHAMENTO DAS REPRODUÇÕES'],
      ['Mãe', 'Pai', 'Status', 'Cobertura', 'Parto previsto', 'Prenhez confirmada', 'Parto', 'Nascimentos'],
      ...data.reproducoes.map(
        (r) => [
          _animal(r.maeId, data),
          _animal(r.paiId, data),
          _status(r.status),
          _date(r.dataCobertura),
          _date(r.dataPrevisaoParto),
          _date(r.dataConfirmacaoPrenhez),
          _date(r.dataParto),
          (data.nascimentosPorReproducao[r.id] ?? const []).length,
        ],
      ),
    ];

    _writeTable(
      sheet,
      rows,
      sectionRow: 0,
      headerRow: 1,
      widths: const {
        0: 28,
        1: 28,
        2: 19,
        3: 16,
        4: 18,
        5: 21,
        6: 16,
        7: 15,
      },
    );

  }

  void _buildNascimentos(Sheet sheet, ReproductionReportData data) {
    final rows = <List<dynamic>>[
      ['NASCIMENTOS'],
      ['Mãe', 'Brinco', 'Sexo', 'Data de nascimento'],
      ...data.reproducoes.expand(
        (r) => (data.nascimentosPorReproducao[r.id] ?? const []).map(
          (n) => [
            _animal(r.maeId, data),
            _animal(n.animalId, data),
            n.sexo == SexoNascimento.femea ? 'Fêmea' : 'Macho',
            _date(n.dataNascimento),
          ],
        ),
      ),
    ];

    _writeTable(
      sheet,
      rows,
      sectionRow: 0,
      headerRow: 1,
      widths: const {
        0: 30,
        1: 30,
        2: 16,
        3: 22,
      },
    );

  }

  void _writeTable(
    Sheet sheet,
    List<List<dynamic>> rows, {
    required int sectionRow,
    required int headerRow,
    required Map<int, double> widths,
  }) {
    final section = _sectionStyle();
    final header = _headerStyle();
    final body = _bodyStyle();
    final alternate = _alternateStyle();

    for (var row = 0; row < rows.length; row++) {
      for (var col = 0; col < rows[row].length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = _cellValue(rows[row][col]);

        if (row == sectionRow) {
          cell.cellStyle = section;
        } else if (row == headerRow) {
          cell.cellStyle = header;
        } else {
          cell.cellStyle = row.isEven ? body : alternate;
        }
      }
    }

    final lastColumn = widths.keys.reduce((a, b) => a > b ? a : b);

    _merge(sheet, 0, lastColumn, sectionRow);

    for (final entry in widths.entries) {
      sheet.setColumnWidth(entry.key, entry.value);
    }

    sheet.setRowHeight(sectionRow, 30);
    sheet.setRowHeight(headerRow, 34);
  }

  void _merge(Sheet sheet, int firstColumn, int lastColumn, int row) {
    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: firstColumn,
        rowIndex: row,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: lastColumn,
        rowIndex: row,
      ),
    );
  }

  CellStyle _titleStyle() => CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        fontSize: 18,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _subtitleStyle() => CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#EAF3E7'),
        fontColorHex: ExcelColor.fromHexString('#263323'),
        fontSize: 12,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _sectionStyle() => CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#DCEBD7'),
        fontColorHex: ExcelColor.fromHexString('#24551D'),
        fontSize: 13,
        bold: true,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _headerStyle() => CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        fontSize: 10,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _labelStyle() => CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#F1F6EF'),
        fontColorHex: ExcelColor.fromHexString('#263323'),
        bold: true,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _valueStyle() => CellStyle(
        fontColorHex: ExcelColor.fromHexString('#263323'),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _bodyStyle() => CellStyle(
        fontColorHex: ExcelColor.fromHexString('#263323'),
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _alternateStyle() => CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#F7F9F5'),
        fontColorHex: ExcelColor.fromHexString('#263323'),
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _mutedStyle() => CellStyle(
        fontColorHex: ExcelColor.fromHexString('#5B6558'),
        fontSize: 10,
        italic: true,
        verticalAlign: VerticalAlign.Center,
      );

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

    return date.day.toString().padLeft(2, '0') +
        '/' +
        date.month.toString().padLeft(2, '0') +
        '/' +
        date.year.toString();
  }

  String _dateTime(DateTime date) {
    return _date(date) +
        ' ' +
        date.hour.toString().padLeft(2, '0') +
        ':' +
        date.minute.toString().padLeft(2, '0');
  }
}
