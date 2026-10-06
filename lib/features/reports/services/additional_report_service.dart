import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdditionalReportService {
  Future<Uint8List> gerarPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final document = pw.Document();
    final green = PdfColor.fromHex('#367C2B');
    final lightGreen = PdfColor.fromHex('#EAF3E7');
    final text = PdfColor.fromHex('#263323');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 30),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Fazenda Baixinha - OviGestão',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
            pw.Text(
              'Página ' +
                  context.pageNumber.toString() +
                  ' de ' +
                  context.pagesCount.toString(),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ],
        ),
        build: (_) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: green,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  subtitle + ' - gerado em ' + _dateTime(DateTime.now()),
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          if (rows.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              color: lightGreen,
              child: pw.Text(
                'Nenhum registro selecionado.',
                style: pw.TextStyle(color: text),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(color: green),
              cellStyle: pw.TextStyle(color: text, fontSize: 7.5),
              cellPadding: const pw.EdgeInsets.all(5),
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#D8E2D4'),
                width: .5,
              ),
            ),
        ],
      ),
    );

    return document.save();
  }

  Future<Uint8List> gerarExcel({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Relatório'];

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
      fontSize: 11,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
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

    final allRows = <List<String>>[
      [title],
      [subtitle + ' - gerado em ' + _dateTime(DateTime.now())],
      [],
      headers,
      ...rows,
    ];

    for (var r = 0; r < allRows.length; r++) {
      for (var c = 0; c < allRows[r].length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        );
        cell.value = TextCellValue(allRows[r][c]);
        if (r == 0) {
          cell.cellStyle = titleStyle;
        } else if (r == 1) {
          cell.cellStyle = subtitleStyle;
        } else if (r == 3) {
          cell.cellStyle = headerStyle;
        }
      }
    }

    final width = headers.length < 3 ? 28.0 : 20.0;
    for (var c = 0; c < headers.length; c++) {
      sheet.setColumnWidth(c, c == 0 ? 16 : width);
    }

    if (headers.length > 1) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(
          columnIndex: headers.length - 1,
          rowIndex: 0,
        ),
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        CellIndex.indexByColumnRow(
          columnIndex: headers.length - 1,
          rowIndex: 1,
        ),
      );
    }

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 22);
    sheet.setRowHeight(3, 26);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    excel.setDefaultSheet('Relatório');

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }


  Future<Uint8List> gerarPdfSecoes({
    required String title,
    required String subtitle,
    required Map<String, List<List<String>>> sections,
  }) async {
    final document = pw.Document();
    final green = PdfColor.fromHex('#367C2B');
    final lightGreen = PdfColor.fromHex('#EAF3E7');
    final text = PdfColor.fromHex('#263323');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 32),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Fazenda Baixinha - OviGestão',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
            pw.Text(
              'Página ' +
                  context.pageNumber.toString() +
                  ' de ' +
                  context.pagesCount.toString(),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ],
        ),
        build: (_) {
          final widgets = <pw.Widget>[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: green,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title.toUpperCase(),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 19,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    subtitle + ' - gerado em ' + _dateTime(DateTime.now()),
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ];

          for (var i = 0; i < sections.length; i++) {
            final sectionTitle = sections.keys.elementAt(i);
            final sectionRows = sections[sectionTitle]!;
            widgets.add(
              pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: i == 0 ? green : lightGreen,
                  borderRadius: pw.BorderRadius.circular(7),
                ),
                child: pw.Text(
                  sectionTitle.toUpperCase(),
                  style: pw.TextStyle(
                    color: i == 0 ? PdfColors.white : text,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );
            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: const ['Indicador', 'Resultado'],
                data: sectionRows,
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: pw.BoxDecoration(color: green),
                cellStyle: pw.TextStyle(color: text, fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#D8E2D4'),
                  width: .5,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 14));
          }

          return widgets;
        },
      ),
    );

    return document.save();
  }

  Future<Uint8List> gerarExcelAbas({
    required String title,
    required String subtitle,
    required Map<String, List<List<String>>> sections,
  }) async {
    final excel = Excel.createExcel();

    for (var index = 0; index < sections.length; index++) {
      final sectionTitle = sections.keys.elementAt(index);
      final sectionRows = sections[sectionTitle]!;
      final sheetName = _sheetName(sectionTitle, index);
      final sheet = excel[sheetName];

      final titleStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#367C2B'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        fontSize: 16,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      final subtitleStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#EAF3E7'),
        fontColorHex: ExcelColor.fromHexString('#263323'),
        fontSize: 10,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
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
      final valueStyle = CellStyle(
        fontSize: 10,
        verticalAlign: VerticalAlign.Center,
      );

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue(title)
        ..cellStyle = titleStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue(
          sectionTitle + ' - ' + subtitle + ' - gerado em ' +
              _dateTime(DateTime.now()),
        )
        ..cellStyle = subtitleStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
        ..value = TextCellValue('Indicador')
        ..cellStyle = headerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3))
        ..value = TextCellValue('Resultado')
        ..cellStyle = headerStyle;

      for (var row = 0; row < sectionRows.length; row++) {
        final values = sectionRows[row];
        for (var col = 0; col < 2; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: col,
              rowIndex: row + 4,
            ),
          );
          cell.value = TextCellValue(values[col]);
          cell.cellStyle = valueStyle;
        }
      }

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0),
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1),
      );
      sheet.setColumnWidth(0, 34);
      sheet.setColumnWidth(1, 52);
      sheet.setRowHeight(0, 26);
      sheet.setRowHeight(1, 24);
      sheet.setRowHeight(3, 24);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    if (sections.isNotEmpty) {
      excel.setDefaultSheet(_sheetName(sections.keys.first, 0));
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  String _sheetName(String value, int index) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?\[\]]'), '')
        .trim();
    final base = cleaned.isEmpty ? 'Seção' : cleaned;
    final numbered = index == 0 ? base : base;
    return numbered.length > 31 ? numbered.substring(0, 31) : numbered;
  }

  String _dateTime(DateTime value) =>
      value.day.toString().padLeft(2, '0') +
      '/' +
      value.month.toString().padLeft(2, '0') +
      '/' +
      value.year.toString() +
      ' ' +
      value.hour.toString().padLeft(2, '0') +
      ':' +
      value.minute.toString().padLeft(2, '0');
}

