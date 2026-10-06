import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/app_asset_icon.dart';
import '../../manejo/models/manejo.dart';
import '../../manejo/services/manejo_service.dart';
import '../services/report_excel_service.dart';
import '../services/report_pdf_service.dart';
import '../widgets/report_period.dart';

class ManejoReportPage extends StatefulWidget {
  final VoidCallback onBack;
  const ManejoReportPage({super.key, required this.onBack});
  @override
  State<ManejoReportPage> createState() => _ManejoReportPageState();
}

class _ManejoReportPageState extends State<ManejoReportPage> {
  final ManejoService _service = ManejoService();
  final ReportPdfService _pdfService = ReportPdfService();
  final ReportExcelService _excelService = ReportExcelService();
  bool _loading = true;
  bool _generating = false;
  String? _error;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _items = [];
  TipoManejo? _type;
  DateTime? _from;
  DateTime? _to;
  ReportPeriod _period = const ReportPeriod.all();
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getManejos();
      if (!mounted) return;
      _all = data;
      setState(() => _loading = false);
      _filter();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  void _filter() {
    final start = _from == null ? null : DateTime(_from!.year, _from!.month, _from!.day);
    final end = _to == null ? null : DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
    final list = _all.where((r) {
      final type = Manejo.tipoFromString(r['tipo']?.toString());
      final date = DateTime.tryParse(r['data']?.toString() ?? '');
      if (_type != null && type != _type) return false;
      if (date == null) return false;
      if (start != null && date.isBefore(start)) return false;
      if (end != null && date.isAfter(end)) return false;
      return true;
    }).toList();
    list.sort((a, b) => (b['data']?.toString() ?? '').compareTo(a['data']?.toString() ?? ''));
    if (mounted) setState(() => _items = list);
  }

  String _manejoId(Map<String, dynamic> r) => r['id']?.toString() ?? ((r['data']?.toString() ?? '') + '|' + (r['tipo']?.toString() ?? '') + '|' + (r['animal_id']?.toString() ?? r['animalId']?.toString() ?? ''));

  List<Map<String, dynamic>> get _selectedItems => _items.where((r) => _selectedIds.contains(_manejoId(r))).toList();

  void _selectAll() => setState(() => _selectedIds.addAll(_items.map(_manejoId)));
  void _clearSelection() => setState(() => _selectedIds.clear());
  void _toggleSelection(Map<String, dynamic> r) {
    setState(() {
      final id = _manejoId(r);
      if (_selectedIds.contains(id)) { _selectedIds.remove(id); } else { _selectedIds.add(id); }
    });
  }

  Future<void> _date(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? (_from ?? DateTime.now()) : (_to ?? _from ?? DateTime.now()),
      firstDate: DateTime(2020), lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) { _from = picked; if (_to != null && _to!.isBefore(picked)) _to = picked; }
      else { _to = picked; if (_from != null && _from!.isAfter(picked)) _from = picked; }
    });
    _filter();
  }

  void _applyPeriod(ReportPeriod value) {
    final range = value.range();
    setState(() { _period = value; _from = range?.$1; _to = range?.$2; _selectedIds.clear(); });
    _filter();
  }

  void _clear() { setState(() { _type = null; _from = null; _to = null; _period = const ReportPeriod.all(); }); _filter(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          AppAssetIcon(assetPath: 'assets/images/icon_manejo.png', size: 26),
          SizedBox(width: 8), Text('Relatório de manejo'),
        ]),
        actions: [
          IconButton(
            tooltip: 'Gerar relatório',
            onPressed: _loading || _items.isEmpty || _selectedItems.isEmpty || _generating ? null : _chooseFormat,
            icon: _generating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
        _error != null ? _errorView() :
        RefreshIndicator(onRefresh: _load, child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [_header(), const SizedBox(height: 14), _filters(), const SizedBox(height: 18), _summary(), const SizedBox(height: 18), _list()],
        )),
    );
  }

  Widget _header() => Card(child: Padding(
    padding: const EdgeInsets.all(18),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppAssetIcon(assetPath: 'assets/images/icon_manejo.png', size: 50),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Relatório de manejo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('Acompanhamento dos manejos registrados na fazenda.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
    ]),
  ));

  Widget _filters() => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Filtros', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      DropdownButtonFormField<TipoManejo>(
        value: _type,
        decoration: const InputDecoration(labelText: 'Tipo de manejo', prefixIcon: Icon(Icons.filter_alt_outlined)),
        items: [
          const DropdownMenuItem<TipoManejo>(child: Text('Todos os tipos')),
          ...TipoManejo.values.map((t) => DropdownMenuItem(value: t, child: Text(_typeName(t)))),
        ],
        onChanged: (v) { setState(() => _type = v); _filter(); },
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _dateButton('Data inicial', _from, () => _date(true))),
        const SizedBox(width: 10),
        Expanded(child: _dateButton('Data final', _to, () => _date(false))),
      ]),
      if (_type != null || _from != null || _to != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _clear, icon: const Icon(Icons.clear), label: const Text('Limpar filtros'))),
    ]),
  ));

  Widget _dateButton(String label, DateTime? date, VoidCallback tap) => OutlinedButton.icon(
    onPressed: tap, icon: const Icon(Icons.calendar_today_outlined, size: 18),
    label: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11)),
      Text(date == null ? 'Selecionar' : _dateText(date)),
    ]),
    style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
  );

  Widget _summary() {
    int count(TipoManejo t) {
      return _items
          .where((r) => Manejo.tipoFromString(r['tipo']?.toString()) == t)
          .length;
    }

    final data = <_Summary>[
      _Summary('Total', _items.length, Icons.assessment_outlined),
      _Summary('Pesagens', count(TipoManejo.pesagem), Icons.monitor_weight_outlined),
      _Summary('Vacinações', count(TipoManejo.vacinacao), Icons.vaccines_outlined),
      _Summary(
        'Vermifugações',
        count(TipoManejo.vermifugacao),
        Icons.medication_outlined,
      ),
      _Summary(
        'Tratamentos',
        count(TipoManejo.tratamento),
        Icons.healing_outlined,
      ),
      _Summary(
        'FAMACHA',
        count(TipoManejo.famacha),
        Icons.health_and_safety_outlined,
      ),
      _Summary('Dentição', count(TipoManejo.denticao), Icons.pets_outlined),
      _Summary(
        'Tosquias',
        count(TipoManejo.tosquia),
        Icons.content_cut_rounded,
      ),
      _Summary(
        'Outros',
        count(TipoManejo.outro),
        Icons.more_horiz_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisExtent: 82,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, i) {
            final s = data[i];
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Row(
                  children: [
                    Icon(s.icon, size: 23),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          Text(
                            s.value.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _list() {
    if (_items.isEmpty) return Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Icon(Icons.assignment_outlined, size: 50, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(height: 10), const Text('Nenhum manejo encontrado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 5), const Text('Não existem registros para os filtros selecionados.', textAlign: TextAlign.center)])));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _selectionBar(),
      const SizedBox(height: 10),
      Row(children: [const Expanded(child: Text('Registros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Text(_items.length.toString() + ' registro(s)', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]),
      const SizedBox(height: 10),
      ..._items.map((r) => _card(r)),
    ]);
  }

  Widget _card(Map<String, dynamic> r) {
    final type = Manejo.tipoFromString(r['tipo']?.toString());
    final date =
        DateTime.tryParse(r['data']?.toString() ?? '') ?? DateTime.now();
    final animal = r['animais'] is Map
        ? Map<String, dynamic>.from(r['animais'])
        : <String, dynamic>{};

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _details(r),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: _selectedIds.contains(_manejoId(r)), onChanged: (_) => _toggleSelection(r)),

              const AppAssetIcon(
                assetPath: 'assets/images/icon_manejo.png',
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _typeName(type),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _dateText(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _animal(animal),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _short(r, type),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionBar() {
    final total = _items.length;
    final selected = _selectedItems.length;
    final allSelected = total > 0 && selected == total;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(child: Text(selected == 0 ? 'Nenhum selecionado' : selected.toString() + ' selecionado(s)', style: const TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: total == 0 || allSelected ? null : _selectAll, child: const Text('Selecionar tudo')),
          TextButton(onPressed: selected == 0 ? null : _clearSelection, child: const Text('Limpar')),
        ]),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar o relatório',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Erro desconhecido.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _chooseFormat() async {
    if (_items.isEmpty || _generating) return;
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Escolha o formato', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('O arquivo será gerado usando os filtros atuais.', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                subtitle: const Text('Relatório visual pronto para compartilhar'),
                onTap: () => Navigator.pop(ctx, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Excel'),
                subtitle: const Text('Planilha .xlsx para editar e analisar'),
                onTap: () => Navigator.pop(ctx, 'excel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (format == null || !mounted) return;
    await _generate(format);
  }

  Future<void> _generate(String format) async {
    setState(() => _generating = true);
    try {
      final registros = _selectedItems.map((item) => Map<String, dynamic>.from(item)).toList();
      final generatedAt = DateTime.now();
      if (format == 'pdf') {
        final bytes = await _pdfService.gerarManejo(registros: registros, generatedAt: generatedAt);
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: const ['ovigestao_relatorio_manejo.pdf'],
          title: 'Relatório de manejo',
          subject: 'Relatório de manejo - Fazenda Baixinha',
        ));
      } else {
        final bytes = await _excelService.gerarManejo(registros: registros, generatedAt: generatedAt);
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          fileNameOverrides: const ['ovigestao_relatorio_manejo.xlsx'],
          title: 'Relatório de manejo',
          subject: 'Planilha de manejo - Fazenda Baixinha',
        ));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((format == 'pdf' ? 'PDF' : 'Excel') + ' gerado com ' + _selectedItems.length.toString() + ' registro(s).')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível gerar o relatório: ' + error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _details(Map<String, dynamic> r) async {
    final type = Manejo.tipoFromString(r['tipo']?.toString());
    final animal = r['animais'] is Map
        ? Map<String, dynamic>.from(r['animais'])
        : <String, dynamic>{};
    final date =
        DateTime.tryParse(r['data']?.toString() ?? '') ?? DateTime.now();

    final details = <String, String>{
      'Data': _dateText(date),
      'Animal': _animal(animal),
      'Tipo': _typeName(type),
    };

    void add(String key, dynamic value) {
      final v = value?.toString().trim();
      if (v != null && v.isNotEmpty) {
        details[key] = v;
      }
    }

    if (type == TipoManejo.pesagem) {
      add('Peso', _weight(r['peso_kg']));
    }
    if (type == TipoManejo.famacha) {
      add('FAMACHA', r['famacha_escore']);
    }
    if (type == TipoManejo.vacinacao) {
      add('Vacina', r['vacina_nome']);
      add('Fabricante', r['vacina_fabricante']);
      add('Lote', r['vacina_lote']);
      add('Dose', _dose(r));
      add('Via', r['via_aplicacao']);
    }
    if (type == TipoManejo.vermifugacao) {
      add('Vermífugo', r['vermifugo_nome']);
      add('Princípio ativo', r['vermifugo_principio_ativo']);
      add('Dose', _dose(r));
      add('Via', r['via_aplicacao']);
    }
    if (type == TipoManejo.tratamento) {
      add('Medicamento', r['medicamento_nome']);
      add('Princípio ativo', r['medicamento_principio_ativo']);
      add('Enfermidade', r['enfermidade']);
      add('Dose', _dose(r));
      add('Via', r['via_aplicacao']);
    }
    if (type == TipoManejo.denticao) {
      add('Dentição', r['denticao']);
      add('Data da dentição', _parsedDate(r['denticao_data']));
    }
    if (type == TipoManejo.tosquia) {
      add('Tipo de tosquia', r['outro_nome']);
      add('Observações da tosquia', r['observacoes']);
    }
    if (type == TipoManejo.outro) {
      add('Descrição', r['outro_nome']);
    }

    add(
      'Carência',
      r['carencia_dias'] == null
          ? null
          : r['carencia_dias'].toString() + ' dia(s)',
    );
    add('Observações', r['observacoes']);

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Detalhes do manejo',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ...details.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            e.key,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(child: Text(e.value)),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _short(Map<String, dynamic> r, TipoManejo type) {
    switch (type) {
      case TipoManejo.pesagem: return 'Peso: ' + (_weight(r['peso_kg']) ?? 'não informado');
      case TipoManejo.famacha: return 'Escore FAMACHA: ' + (r['famacha_escore']?.toString() ?? 'não informado');
      case TipoManejo.vacinacao: return 'Vacina: ' + (r['vacina_nome']?.toString() ?? 'não informada');
      case TipoManejo.vermifugacao: return 'Vermífugo: ' + (r['vermifugo_nome']?.toString() ?? 'não informado');
      case TipoManejo.tratamento: return 'Medicamento: ' + (r['medicamento_nome']?.toString() ?? 'não informado');
      case TipoManejo.denticao: return 'Dentição: ' + (r['denticao']?.toString() ?? 'não informada');
      case TipoManejo.outro: return r['outro_nome']?.toString() ?? 'Outro manejo';
      case TipoManejo.tosquia: return 'Registro de tosquia';
    }
  }

  String _animal(Map<String, dynamic> a) {
    final b = a['brinco']?.toString(); final n = a['nome']?.toString();
    if (b != null && b.isNotEmpty && n != null && n.isNotEmpty) return 'Brinco ' + b + ' - ' + n;
    if (b != null && b.isNotEmpty) return 'Brinco ' + b;
    if (n != null && n.isNotEmpty) return n;
    return 'Animal não identificado';
  }

  String? _weight(dynamic v) { final n = v is num ? v.toDouble() : double.tryParse(v?.toString().replaceAll(',', '.') ?? ''); return n == null ? null : n.toStringAsFixed(1) + ' kg'; }
  String? _dose(Map<String, dynamic> r) { final v = r['dose']; if (v == null) return null; final u = r['dose_unidade']?.toString(); return v.toString() + (u == null || u.isEmpty ? '' : ' ' + u); }
  String? _parsedDate(dynamic v) { final d = DateTime.tryParse(v?.toString() ?? ''); return d == null ? null : _dateText(d); }
  String _dateText(DateTime d) => d.day.toString().padLeft(2, '0') + '/' + d.month.toString().padLeft(2, '0') + '/' + d.year.toString();

  String _typeName(TipoManejo t) {
    switch (t) {
      case TipoManejo.vacinacao: return 'Vacinação';
      case TipoManejo.vermifugacao: return 'Vermifugação';
      case TipoManejo.tratamento: return 'Tratamento';
      case TipoManejo.tosquia: return 'Tosquia';
      case TipoManejo.pesagem: return 'Pesagem';
      case TipoManejo.famacha: return 'FAMACHA';
      case TipoManejo.denticao: return 'Dentição';
      case TipoManejo.outro: return 'Outro';
    }
  }
}

class _Summary {
  final String name; final int value; final IconData icon;
  const _Summary(this.name, this.value, this.icon);
}