import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../animals/models/animal.dart';
import '../../animals/services/animal_service.dart';
import '../../reproduction/models/reproducao.dart';
import '../../reproduction/models/reproducao_nascimento.dart';
import '../../reproduction/services/reproducao_service.dart';
import '../models/reproduction_report_data.dart';
import '../services/reproduction_report_excel_service.dart';
import '../services/reproduction_report_pdf_service.dart';

class ReproducaoReportPage extends StatefulWidget {
  final VoidCallback onBack;
  const ReproducaoReportPage({super.key, required this.onBack});
  @override
  State<ReproducaoReportPage> createState() => _ReproducaoReportPageState();
}

class _ReproducaoReportPageState extends State<ReproducaoReportPage> {
  final _repro = ReproducaoService();
  final _animals = AnimalService();
  final _pdf = ReproductionReportPdfService();
  final _excel = ReproductionReportExcelService();

  List<Reproducao> _items = [];
  Map<String, List<ReproducaoNascimento>> _births = {};
  Map<String, Animal> _animalMap = {};
  bool _loading = true;
  bool _generating = false;
  String? _error;
  String _status = 'Todos';
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _repro.getReproducoes();
      final rows = await _animals.getTodosAnimais();
      final map = <String, Animal>{
        for (final row in rows)
          if (row['id'] != null) row['id'].toString(): Animal.fromMap(row),
      };
      final births = <String, List<ReproducaoNascimento>>{};
      await Future.wait(items.map((item) async {
        births[item.id] = await _repro.getNascimentos(item.id);
      }));
      if (!mounted) return;
      setState(() { _items = items; _animalMap = map; _births = births; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  String _statusLabel(StatusReproducao s) => switch (s) {
    StatusReproducao.planejada => 'Planejada',
    StatusReproducao.coberta => 'Coberta',
    StatusReproducao.prenhe => 'Prenhe',
    StatusReproducao.naoPrenhe => 'Não prenhe',
    StatusReproducao.abortou => 'Abortou',
    StatusReproducao.partoRealizado => 'Parto realizado',
    StatusReproducao.encerrada => 'Encerrada',
  };

  String _date(DateTime? d) => d == null ? 'Não informada' :
      d.day.toString().padLeft(2, '0') + '/' +
      d.month.toString().padLeft(2, '0') + '/' + d.year.toString();

  String _animal(String? id) {
    if (id == null || id.trim().isEmpty) return 'Não informado';
    final a = _animalMap[id];
    if (a == null) return 'Não informado';
    final n = a.nome?.trim();
    return n == null || n.isEmpty ? 'Brinco ' + a.brinco : a.brinco + ' • ' + n;
  }

  List<Reproducao> get _filtered => _items.where((r) {
    final statusOk = _status == 'Todos' || _statusName(r.status) == _status;
    final d = r.dataCobertura ?? r.dataConfirmacaoPrenhez ?? r.dataParto ?? r.criadoEm;
    final fromOk = _from == null || (d != null && !_day(d).isBefore(_day(_from!)));
    final toOk = _to == null || (d != null && !_day(d).isAfter(_day(_to!)));
    return statusOk && fromOk && toOk;
  }).toList();

  String _statusName(StatusReproducao s) => _statusLabel(s);

  Future<void> _pickDate(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: from ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (from) { _from = d; if (_to != null && _to!.isBefore(d)) _to = d; }
      else { _to = d; if (_from != null && d.isBefore(_from!)) _from = d; }
    });
  }

  Future<void> _chooseFormat() async {
    if (_filtered.isEmpty || _generating) return;
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('Escolha o formato', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          ),
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('PDF'), subtitle: const Text('Relatório visual'), onTap: () => Navigator.pop(context, 'pdf')),
          ListTile(leading: const Icon(Icons.table_view_outlined), title: const Text('Excel'), subtitle: const Text('Planilha para análise'), onTap: () => Navigator.pop(context, 'excel')),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (format != null && mounted) _generate(format);
  }

  Future<void> _generate(String format) async {
    setState(() => _generating = true);
    try {
      final selected = _filtered;
      final data = ReproductionReportData(
        reproducoes: selected,
        nascimentosPorReproducao: {for (final r in selected) r.id: _births[r.id] ?? const []},
        animaisPorId: _animalMap,
        generatedAt: DateTime.now(),
      );
      if (format == 'pdf') {
        final bytes = await _pdf.gerar(data);
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: const ['ovigestao_relatorio_reproducao.pdf'],
          title: 'Relatório de reprodução',
        ));
      } else {
        final bytes = await _excel.gerar(data);
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          fileNameOverrides: const ['ovigestao_relatorio_reproducao.xlsx'],
          title: 'Planilha de reprodução',
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível gerar: ' + e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final data = ReproductionReportData(
      reproducoes: list,
      nascimentosPorReproducao: {for (final r in list) r.id: _births[r.id] ?? const []},
      animaisPorId: _animalMap,
      generatedAt: DateTime.now(),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          AppAssetIcon(assetPath: 'assets/images/icon_cobertura.png', size: 26),
          SizedBox(width: 8), Text('Relatório de reprodução'),
        ]),
        actions: [IconButton(
          tooltip: 'Gerar relatório',
          onPressed: list.isEmpty || _generating ? null : _chooseFormat,
          icon: _generating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share_rounded),
        )],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
        _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
        ])) :
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _Summary(data: data),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['Todos','Planejada','Coberta','Prenhe','Não prenhe','Abortou','Parto realizado','Encerrada']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) { if (v != null) setState(() => _status = v); },
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.calendar_today_outlined), label: Text(_from == null ? 'Data inicial' : _date(_from)))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.event_outlined), label: Text(_to == null ? 'Data final' : _date(_to)))),
              ]),
              if (_from != null || _to != null)
                Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() { _from = null; _to = null; }), icon: const Icon(Icons.clear), label: const Text('Limpar datas'))),
              const SizedBox(height: 8),
              Text(list.isEmpty ? 'Nenhuma reprodução encontrada' : list.length.toString() + ' reprodução(ões) no relatório', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...list.map((r) => _Card(
                r: r,
                mae: _animal(r.maeId),
                pai: _animal(r.paiId),
                births: _births[r.id] ?? const [],
              )),
            ],
          ),
        ),
    );
  }
}

class _Summary extends StatelessWidget {
  final ReproductionReportData data;
  const _Summary({required this.data});
  @override
  Widget build(BuildContext context) {
    final values = [
      ['Reproduções', data.total], ['Prenhes', data.prenhes],
      ['Partos', data.partos], ['Nascimentos', data.totalNascimentos],
      ['Fêmeas', data.femeasNascidas], ['Machos', data.machosNascidos],
    ];
    return GridView.count(
      crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 2.2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: values.map((v) => Card(
        margin: EdgeInsets.zero, elevation: 0,
        child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          const AppAssetIcon(assetPath: 'assets/images/icon_reproducao.png', size: 26),
          const SizedBox(width: 9),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(v[1].toString(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text(v[0].toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ]),
        ])),
      )).toList(),
    );
  }
}

class _Card extends StatelessWidget {
  final Reproducao r;
  final String mae;
  final String pai;
  final List<ReproducaoNascimento> births;
  const _Card({required this.r, required this.mae, required this.pai, required this.births});

  String _date(DateTime? d) => d == null ? 'Não informada' :
      d.day.toString().padLeft(2,'0') + '/' + d.month.toString().padLeft(2,'0') + '/' + d.year.toString();

  @override
  Widget build(BuildContext context) {
    final color = switch (r.status) {
      StatusReproducao.prenhe => Colors.green,
      StatusReproducao.abortou => Colors.red,
      StatusReproducao.partoRealizado => Colors.teal,
      StatusReproducao.naoPrenhe => Colors.orange,
      StatusReproducao.coberta => Colors.blue,
      _ => Colors.blueGrey,
    };
    final status = switch (r.status) {
      StatusReproducao.planejada => 'Planejada',
      StatusReproducao.coberta => 'Coberta',
      StatusReproducao.prenhe => 'Prenhe',
      StatusReproducao.naoPrenhe => 'Não prenhe',
      StatusReproducao.abortou => 'Abortou',
      StatusReproducao.partoRealizado => 'Parto realizado',
      StatusReproducao.encerrada => 'Encerrada',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: const AppAssetIcon(assetPath: 'assets/images/icon_cobertura.png', size: 26)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mãe: ' + mae, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('Pai: ' + pai, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 8, children: [
          if (r.dataCobertura != null) Text('Cobertura: ' + _date(r.dataCobertura)),
          if (r.dataPrevisaoParto != null) Text('Parto previsto: ' + _date(r.dataPrevisaoParto)),
          if (r.dataConfirmacaoPrenhez != null) Text('Prenhez: ' + _date(r.dataConfirmacaoPrenhez)),
          if (r.dataParto != null) Text('Parto: ' + _date(r.dataParto)),
        ]),
        if (births.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Nascimentos: ' + births.length.toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
      ])),
    );
  }
}
