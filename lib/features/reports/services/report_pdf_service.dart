import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report_data.dart';
import '../../animals/models/animal.dart';

class ReportPdfService {
  Future<Uint8List> gerarRebanho(ReportData data) async {
    final document = pw.Document();

    final green = PdfColor.fromHex('#367C2B');
    final lightGreen = PdfColor.fromHex('#EAF3E7');
    final text = PdfColor.fromHex('#263323');
    final muted = PdfColor.fromHex('#667060');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 34),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Fazenda Baixinha • OviGestão',
              style: pw.TextStyle(fontSize: 8, color: muted),
            ),
            pw.Text(
              'Página ' +
                  context.pageNumber.toString() +
                  ' de ' +
                  context.pagesCount.toString(),
              style: pw.TextStyle(fontSize: 8, color: muted),
            ),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: green,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RELATÓRIO DO REBANHO',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Fazenda Baixinha • gerado em ' + _dateTime(data.generatedAt),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _card('Total', data.total.toString(), green, lightGreen),
              _card('Ativos', data.ativos.toString(), green, lightGreen),
              _card('Fêmeas', data.femeas.toString(), green, lightGreen),
              _card('Machos', data.machos.toString(), green, lightGreen),
              _card('Vendidos', data.vendidos.toString(), green, lightGreen),
              _card('Mortos', data.mortos.toString(), green, lightGreen),
              _card('Descartados', data.descartados.toString(), green, lightGreen),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Composição por raça', text),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              _headerRow(['Raça', 'Quantidade', '%'], green),
              ...data.porRaca.entries.map(
                (entry) => pw.TableRow(
                  children: [
                    _cell(entry.key),
                    _cell(entry.value.toString(), align: pw.TextAlign.center),
                    _cell('${data.percentualRaca(entry.value).toStringAsFixed(1)}%', align: pw.TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Animais', text),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
            columnWidths: const {
              0: pw.FixedColumnWidth(45),
              1: pw.FlexColumnWidth(1.7),
              2: pw.FixedColumnWidth(45),
              3: pw.FlexColumnWidth(2.8),
              4: pw.FixedColumnWidth(55),
              5: pw.FlexColumnWidth(1.0),
            },
            children: [
              _headerRow(
                [
                  'Brinco',
                  'Nome',
                  'Sexo',
                  'Composição racial',
                  'Nascimento',
                  'Status',
                ],
                green,
              ),
              ...data.animals.map(
                (animal) => pw.TableRow(
                  children: [
                    _cell(animal.brinco, align: pw.TextAlign.center),
                    _cell(_nome(animal.nome)),
                    _cell(_sexo(animal.sexo), align: pw.TextAlign.center),
                    _cell(_composicao(data.composicoesPorAnimal[animal.id])),
                    _cell(
                      _date(animal.dataNascimento),
                      align: pw.TextAlign.center,
                    ),
                    _cell(_status(animal.status), align: pw.TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _card(
    String label,
    String value,
    PdfColor green,
    PdfColor background,
  ) {
    return pw.Container(
      width: 88,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              color: green,
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title, PdfColor text) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        color: text,
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.TableRow _headerRow(List<String> values, PdfColor green) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: green),
      children: values.map(
        (value) => pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ).toList(),
    );
  }

  pw.Widget _cell(String value, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        value,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 7),
      ),
    );
  }

  String _nome(String? value) =>
      value == null || value.trim().isEmpty ? 'Não informado' : value.trim();

  String _composicao(List<dynamic>? composicoes) {
    if (composicoes == null || composicoes.isEmpty) {
      return 'Não informada';
    }

    return composicoes.map((item) {
      final nome = item.racaNome.toString().trim();
      final percentual = item.percentual as double;
      final percentualTexto = percentual % 1 == 0
          ? percentual.toStringAsFixed(0)
          : percentual.toStringAsFixed(1);

      return percentualTexto + '% ' + (nome.isEmpty ? 'Não informada' : nome);
    }).join(' + ');
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

  String _sexo(SexoAnimal sexo) => sexo == SexoAnimal.femea ? 'Fêmea' : 'Macho';

  String _status(StatusAnimal status) => switch (status) {
        StatusAnimal.ativo => 'Ativo',
        StatusAnimal.vendido => 'Vendido',
        StatusAnimal.morto => 'Morto',
        StatusAnimal.descartado => 'Descartado',
      };
}
