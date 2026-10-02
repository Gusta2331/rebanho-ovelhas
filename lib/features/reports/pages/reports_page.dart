import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../../core/widgets/contextual_help.dart';
import '../models/report_type.dart';
import '../../animals/models/animal.dart';
import '../../animals/services/animal_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportType? _selectedType;

  @override
  Widget build(BuildContext context) {
    if (_selectedType == ReportType.rebanho) {
      return _RebanhoReport(
        onBack: () => setState(() => _selectedType = null),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(
              assetPath: 'assets/images/icon_relatorios.png',
              size: 26,
            ),
            SizedBox(width: 8),
            Text('Relatórios'),
          ],
        ),
        actions: const [
          ContextualHelpButton(
            title: 'Relatórios',
            introduction:
                'Escolha o tipo de relatório que deseja consultar ou gerar.',
            topics: [
              HelpTopic(
                title: 'Formatos',
                description:
                    'Os relatórios serão preparados para PDF e Excel, com o formato escolhido por você.',
              ),
              HelpTopic(
                title: 'Categorias',
                description:
                    'Cada categoria reúne informações específicas da Fazenda Baixinha.',
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ReportsHeader(),
          const SizedBox(height: 20),
          ...ReportType.values.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(
                type: type,
                onTap: () => setState(() => _selectedType = type),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Central de relatórios',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Analise os dados da fazenda e escolha o relatório que deseja gerar.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportType type;
  final VoidCallback onTap;

  const _ReportCard({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: AppAssetIcon(
                  assetPath: type.iconAsset,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RebanhoReport extends StatefulWidget {
  final VoidCallback onBack;

  const _RebanhoReport({required this.onBack});

  @override
  State<_RebanhoReport> createState() => _RebanhoReportState();
}

class _RebanhoReportState extends State<_RebanhoReport> {
  final _service = AnimalService();
  final _search = TextEditingController();

  List<Animal> _animals = [];
  bool _loading = true;
  String _status = 'Todos';
  String? _error;

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
      final matchesStatus =
          _status == 'Todos' ||
          switch (_status) {
            'Ativos' => animal.status == StatusAnimal.ativo,
            'Vendidos' => animal.status == StatusAnimal.vendido,
            'Mortos' => animal.status == StatusAnimal.morto,
            'Descartados' => animal.status == StatusAnimal.descartado,
            _ => true,
          };

      final matchesSearch =
          query.isEmpty ||
          animal.brinco.toLowerCase().contains(query) ||
          (animal.nome?.toLowerCase().contains(query) ?? false) ||
          animal.raca.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  String _date(DateTime? value) => value == null
      ? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _statusName(StatusAnimal status) => switch (status) {
    StatusAnimal.ativo => 'Ativo',
    StatusAnimal.vendido => 'Vendido',
    StatusAnimal.morto => 'Morto',
    StatusAnimal.descartado => 'Descartado',
  };

  Future<void> _exportSpreadsheet() async {
    final rows = _filtered;
    if (rows.isEmpty) return;

    const header = [
      'Brinco',
      'Nome',
      'Sexo',
      'Raça',
      'Nascimento',
      'Status',
      'Origem',
      'Mãe (ID)',
      'Pai (ID)',
    ];

    final table = <List<String>>[
      header,
      ...rows.map(
        (animal) => [
          animal.brinco,
          animal.nome ?? '',
          animal.sexo == SexoAnimal.femea ? 'Fêmea' : 'Macho',
          animal.raca,
          _date(animal.dataNascimento),
          _statusName(animal.status),
          animal.origem == OrigemAnimal.nascido ? 'Nascido' : 'Comprado',
          animal.idMae ?? '',
          animal.idPai ?? '',
        ],
      ),
    ];

    final csv =
        '\uFEFF${table.map((row) => row.map(_csvCell).join(';')).join('\r\n')}';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(csv),
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: const ['ovigestao_rebanho.csv'],
        title: 'Exportar rebanho',
        subject: 'Relatório do rebanho',
        text: 'Planilha do rebanho com ${rows.length} animais.',
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Planilha com ${rows.length} animais pronta para salvar ou abrir no Excel.',
        ),
      ),
    );
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

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
            tooltip: 'Exportar planilha',
            onPressed: _filtered.isEmpty ? null : _exportSpreadsheet,
            icon: const Icon(Icons.table_view_outlined),
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
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
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
                      _RebanhoSummary(
                        total: _animals.length,
                        filtered: _filtered.length,
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
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Situação',
                        ),
                        items: const [
                          'Todos',
                          'Ativos',
                          'Vendidos',
                          'Mortos',
                          'Descartados',
                        ]
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _status = value ?? 'Todos');
                        },
                      ),
                      const SizedBox(height: 16),
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
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.primaryColor.withValues(
                                  alpha: 0.10,
                                ),
                                child: const Icon(
                                  Icons.description_outlined,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              title: Text(
                                animal.nome?.trim().isNotEmpty == true
                                    ? '${animal.nome} · ${animal.brinco}'
                                    : 'Brinco ${animal.brinco}',
                              ),
                              subtitle: Text(
                                '${animal.raca} · ${_statusName(animal.status)} · ${_date(animal.dataNascimento).isEmpty ? 'Nascimento não informado' : _date(animal.dataNascimento)}',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _RebanhoSummary extends StatelessWidget {
  final int total;
  final int filtered;

  const _RebanhoSummary({
    required this.total,
    required this.filtered,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Total',
            value: '$total',
            icon: Icons.groups_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'No filtro',
            value: '$filtered',
            icon: Icons.filter_alt_outlined,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
