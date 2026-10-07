import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../animals/models/animal.dart';
import '../../animals/services/composicao_racial_service.dart';
import '../../animals/services/animal_service.dart';
import '../models/report_data.dart';
import '../services/report_excel_service.dart';
import '../services/report_pdf_service.dart';
import '../widgets/report_period.dart';
import '../widgets/report_age.dart';

class RebanhoReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const RebanhoReportPage({super.key, required this.onBack});

  @override
  State<RebanhoReportPage> createState() => _RebanhoReportPageState();
}

class _RebanhoReportPageState extends State<RebanhoReportPage> {
  final _service = AnimalService();
  final _composicaoRacialService = ComposicaoRacialService();
  final _search = TextEditingController();
  final _pdfService = ReportPdfService();
  final _excelService = ReportExcelService();

  List<Animal> _animals = [];
  bool _loading = true;
  bool _generating = false;
  String? _error;
  String _status = 'Todos';
  String _sexo = 'Todos';
  String _raca = 'Todas';
  final Set<String> _selectedIds = <String>{};
  ReportPeriod _period = const ReportPeriod.all();
  ReportAge _age = const ReportAge.all();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _service.getTodosAnimais();
      if (!mounted) return;
      setState(() {
        _animals = rows.map(Animal.fromMap).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Animal> get _filtered {
    final query = _search.text.trim().toLowerCase();

    return _animals.where((animal) {
      final matchesStatus = _status == 'Todos' || switch (_status) {
        'Ativos' => animal.status == StatusAnimal.ativo,
        'Vendidos' => animal.status == StatusAnimal.vendido,
        'Mortos' => animal.status == StatusAnimal.morto,
        'Descartados' => animal.status == StatusAnimal.descartado,
        _ => true,
      };

      final matchesSexo = _sexo == 'Todos' ||
          (_sexo == 'Fêmeas' && animal.sexo == SexoAnimal.femea) ||
          (_sexo == 'Machos' && animal.sexo == SexoAnimal.macho);

      final matchesRaca = _raca == 'Todas' || animal.raca == _raca;

      final matchesSearch = query.isEmpty ||
          animal.brinco.toLowerCase().contains(query) ||
          (animal.nome?.toLowerCase().contains(query) ?? false) ||
          animal.raca.toLowerCase().contains(query);

      final range = _period.range();
      final eventDates = <DateTime?>[
        animal.dataNascimento,
        animal.dataEntrada,
        animal.dataSaida,
        animal.dataAquisicao,
      ];
      final periodOk = range == null ||
          eventDates.any((date) =>
              date != null &&
              !date.isBefore(range.$1) &&
              !date.isAfter(range.$2));
      final ageOk = _age.matches(animal.dataNascimento);
      return matchesStatus &&
          matchesSexo &&
          matchesRaca &&
          matchesSearch &&
          periodOk &&
          ageOk;
    }).toList();
  }

  List<String> get _racas {
    final values = _animals
        .map((animal) => animal.raca.trim())
        .where((raca) => raca.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Todas', ...values];
  }

  List<Animal> get _selectedAnimals => _filtered.where((a) => _selectedIds.contains(a.id.toString())).toList();

  void _selectAll() => setState(() => _selectedIds.addAll(_filtered.map((a) => a.id.toString())));
  void _clearSelection() => setState(() => _selectedIds.clear());

  void _toggleSelection(Animal animal) {
    setState(() {
      final id = animal.id.toString();
      if (_selectedIds.contains(id)) { _selectedIds.remove(id); } else { _selectedIds.add(id); }
    });
  }

  Future<void> _chooseFormat() async {
    if (_filtered.isEmpty || _generating || _selectedAnimals.isEmpty) return;

    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escolha o formato',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'O relatório será gerado com os filtros atuais.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                subtitle: const Text('Relatório visual pronto para compartilhar'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Excel'),
                subtitle: const Text('Planilha .xlsx para editar e analisar'),
                onTap: () => Navigator.pop(context, 'excel'),
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
      final animals = List<Animal>.from(_selectedAnimals);
      final composicoes = await _composicaoRacialService.listarPorAnimais(
        animals.map((animal) => animal.id).toList(),
      );

      final data = ReportData(
        animals: animals,
        generatedAt: DateTime.now(),
        composicoesPorAnimal: composicoes,
        periodLabel: _period.label + ' | Idade: ' + _age.label,
      );

      if (format == 'pdf') {
        final bytes = await _pdfService.gerarRebanho(data);
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(bytes, mimeType: 'application/pdf'),
            ],
            fileNameOverrides: const ['ovigestao_relatorio_rebanho.pdf'],
            title: 'Relatório do rebanho',
            subject: 'Relatório do rebanho - Fazenda Baixinha',
          ),
        );
      } else {
        final bytes = await _excelService.gerarRebanho(data);
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              ),
            ],
            fileNameOverrides: const ['ovigestao_relatorio_rebanho.xlsx'],
            title: 'Relatório do rebanho',
            subject: 'Planilha do rebanho - Fazenda Baixinha',
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (format == 'pdf' ? 'PDF' : 'Excel') +
                ' gerado com ' +
                data.total.toString() +
                ' animais.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível gerar o relatório: ' +
                error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(
              assetPath: 'assets/images/icon_animais.png',
              size: 26,
            ),
            SizedBox(width: 8),
            Text('Relatório do rebanho'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gerar relatório',
            onPressed: _filtered.isEmpty || _selectedAnimals.isEmpty || _generating ? null : _chooseFormat,
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      ReportPeriodCard(
                        value: _period,
                        onChanged: (value) => setState(() {
                          _period = value;
                          _selectedIds.clear();
                        }),
                      ),
                      const SizedBox(height: 10),
                      ReportAgeCard(
                        value: _age,
                        onChanged: (value) => setState(() {
                          _age = value;
                          _selectedIds.clear();
                        }),
                      ),
                      const SizedBox(height: 12),
                      _Summary(
                        total: _animals.length,
                        filtered: _filtered.length,
                        femeas: _filtered.where((a) => a.sexo == SexoAnimal.femea).length,
                        machos: _filtered.where((a) => a.sexo == SexoAnimal.macho).length,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          labelText: 'Buscar animal',
                          hintText: 'Nome, brinco ou raça',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _search.clear,
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _dropdown(
                              label: 'Situação',
                              value: _status,
                              values: const [
                                'Todos',
                                'Ativos',
                                'Vendidos',
                                'Mortos',
                                'Descartados',
                              ],
                              onChanged: (value) => setState(() => _status = value),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dropdown(
                              label: 'Sexo',
                              value: _sexo,
                              values: const ['Todos', 'Fêmeas', 'Machos'],
                              onChanged: (value) => setState(() => _sexo = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _dropdown(
                        label: 'Raça',
                        value: _raca,
                        values: _racas,
                        onChanged: (value) => setState(() => _raca = value),
                      ),
                      const SizedBox(height: 16),
                      _selectionBar(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _filtered.isEmpty
                                  ? 'Nenhum animal encontrado'
                                  : _filtered.length.toString() +
                                      ' animal(is) no relatório',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_filtered.isNotEmpty)
                            TextButton.icon(
                              onPressed: _chooseFormat,
                              icon: const Icon(Icons.description_outlined),
                              label: const Text('Gerar selecionados'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum animal corresponde aos filtros.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ..._filtered.map(
                          (animal) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: CheckboxListTile(
                              value: _selectedIds.contains(animal.id.toString()),
                              onChanged: (_) => _toggleSelection(animal),
                              controlAffinity: ListTileControlAffinity.leading,
                              secondary: CircleAvatar(
                                backgroundColor:
                                    AppTheme.primaryColor.withValues(alpha: .10),
                                child: AppAssetIcon(
                                  assetPath: animal.sexo == SexoAnimal.femea
                                      ? 'assets/images/icon_ovino_femea.png'
                                      : 'assets/images/icon_ovino_macho.png',
                                  size: 25,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(animal.nome?.trim().isNotEmpty == true ? animal.nome!.trim() : 'Brinco ' + animal.brinco, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  Text(animal.brinco, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                ],
                              ),
                              subtitle: Text(animal.raca),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _selectionBar() {
    final total = _filtered.length;
    final selected = _selectedAnimals.length;
    final allSelected = total > 0 && selected == total;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                selected == 0 ? 'Nenhum selecionado' : selected.toString() + ' selecionado(s)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: total == 0 ? null : (allSelected ? null : _selectAll),
              child: const Text('Selecionar tudo'),
            ),
            TextButton(
              onPressed: selected == 0 ? null : _clearSelection,
              child: const Text('Limpar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : values.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final int total;
  final int filtered;
  final int femeas;
  final int machos;

  const _Summary({
    required this.total,
    required this.filtered,
    required this.femeas,
    required this.machos,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryCard('Total', total.toString(), 'assets/images/icon_animais.png'),
        _SummaryCard('Filtrados', filtered.toString(), 'assets/images/icon_lotes.png'),
        _SummaryCard('Fêmeas', femeas.toString(), 'assets/images/icon_ovino_femea.png'),
        _SummaryCard('Machos', machos.toString(), 'assets/images/icon_ovino_macho.png'),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String iconAsset;

  const _SummaryCard(this.label, this.value, this.iconAsset);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AppAssetIcon(assetPath: iconAsset, size: 24),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
