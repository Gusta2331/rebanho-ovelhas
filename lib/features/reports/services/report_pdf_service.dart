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
              'Fazenda Baixinha - OviGestão',
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
                  'Fazenda Baixinha - gerado em ' + _dateTime(data.generatedAt),
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
              3: pw.FlexColumnWidth(1.6),
              4: pw.FixedColumnWidth(55),
              5: pw.FlexColumnWidth(1.0),
              6: pw.FlexColumnWidth(2.2),
            },
            children: [
              _headerRow(
                ['Brinco', 'Nome', 'Sexo', 'Raça', 'Nascimento', 'Status', 'Composição racial'],
                green,
              ),
              ...data.animals.map(
                (animal) => pw.TableRow(
                  children: [
                    _cell(animal.brinco, align: pw.TextAlign.center),
                    _cell(_nome(animal.nome)),
                    _cell(_sexo(animal.sexo), align: pw.TextAlign.center),
                    _cell(_raca(animal.raca)),
                    _cell(_date(animal.dataNascimento), align: pw.TextAlign.center),
                    _cell(_status(animal.status), align: pw.TextAlign.center),
                    _cell(_composicao(data.composicoesPorAnimal[animal.id])),
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

  String _raca(String value) =>
      value.trim().isEmpty ? 'Não informada' : value.trim();

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
  String _status(StatusAnimal status) => switch (status) {
        StatusAnimal.ativo => 'Ativo',
        StatusAnimal.vendido => 'Vendido',
        StatusAnimal.morto => 'Morto',
        StatusAnimal.descartado => 'Descartado',
      };

  Future<Uint8List> gerarManejo({
    required List<Map<String, dynamic>> registros,
    required DateTime generatedAt,
  }) async {
    final document = pw.Document();
    final green = PdfColor.fromHex('#367C2B');
    final lightGreen = PdfColor.fromHex('#EAF3E7');
    final text = PdfColor.fromHex('#263323');
    final muted = PdfColor.fromHex('#667060');

    int count(String tipo) => registros.where((r) => r['tipo']?.toString() == tipo).length;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 34),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Fazenda Baixinha - OviGestão', style: pw.TextStyle(fontSize: 8, color: muted)),
            pw.Text('Página ' + context.pageNumber.toString() + ' de ' + context.pagesCount.toString(), style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(color: green, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RELATÓRIO DE MANEJO', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('Fazenda Baixinha - gerado em ' + _manejoDateTime(generatedAt), style: pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _card('Total', registros.length.toString(), green, lightGreen),
              _card('Pesagens', count('pesagem').toString(), green, lightGreen),
              _card('Vacinações', count('vacinacao').toString(), green, lightGreen),
              _card('Vermifugações', count('vermifugacao').toString(), green, lightGreen),
              _card('Tratamentos', count('tratamento').toString(), green, lightGreen),
              _card('FAMACHA', count('famacha').toString(), green, lightGreen),
              _card('Dentição', count('denticao').toString(), green, lightGreen),
              _card('Tosquias', count('tosquia').toString(), green, lightGreen),
              _card('Outros', count('outro').toString(), green, lightGreen),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Registros de manejo', text),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
            columnWidths: const {
              0: pw.FixedColumnWidth(48),
              1: pw.FixedColumnWidth(66),
              2: pw.FixedColumnWidth(92),
              3: pw.FixedColumnWidth(170),
              4: pw.FixedColumnWidth(90),
            },
            children: [
              _headerRow(['Data', 'Tipo', 'Animal', 'Detalhamento', 'Observações'], green),
              ...registros.map((r) => pw.TableRow(children: [
                _cell(_manejoDate(r['data']), align: pw.TextAlign.center),
                _cell(_manejoType(r['tipo'])),
                _cell(_manejoAnimal(r['animais'])),
                _cell(_manejoDetail(r)),
                _cell(_manejoText(r['observacoes'])),
              ])),
            ],
          ),
        ],
      ),
    );
    return document.save();
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
      case 'vacinacao':
        return 'Vacina: ' + _manejoText(r['vacina_nome']) +
            ' - Dose: ' + _manejoDose(r) +
            ' - Via: ' + _manejoText(r['via_aplicacao']);
      case 'vermifugacao':
        return 'Vermífugo: ' + _manejoText(r['vermifugo_nome']) +
            ' - Dose: ' + _manejoDose(r) +
            ' - Via: ' + _manejoText(r['via_aplicacao']);
      case 'tratamento':
        return 'Medicamento: ' + _manejoText(r['medicamento_nome']) +
            ' - Enfermidade: ' + _manejoText(r['enfermidade']) +
            ' - Dose: ' + _manejoDose(r) +
            ' - Via: ' + _manejoText(r['via_aplicacao']);
      case 'denticao':
        return 'Dentição: ' + _manejoText(r['denticao']);
      case 'tosquia':
        return 'Tosquia: ' + _manejoText(r['outro_nome']);
      default:
        return _manejoText(r['outro_nome']);
    }
  }

}
