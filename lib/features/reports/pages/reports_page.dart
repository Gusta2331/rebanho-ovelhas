import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/contextual_help.dart';
import '../../animals/models/animal.dart';
import '../../animals/services/animal_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
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
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
        files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
        fileNameOverrides: const ['ovigestao_rebanho.csv'],
        title: 'Exportar criação',
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Relatórios'),
      actions: const [
        ContextualHelpButton(
          title: 'Relatórios do rebanho',
          introduction:
              'Consulte e prepare uma planilha com os animais cadastrados.',
          topics: [
            HelpTopic(
              title: 'Filtrar',
              description: 'Use a busca, o nome, o brinco ou a raça e escolha uma situação do animal.',
            ),
            HelpTopic(
              title: 'Levar para o Excel',
              description: 'Gere um arquivo CSV que pode ser salvo ou aberto no Excel. Os filtros atuais definem quais animais entram no arquivo.',
            ),
          ],
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.pets, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_filtered.length} animais no relatório',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Exportar planilha para Excel',
                          onPressed: _filtered.isEmpty
                              ? null
                              : _exportSpreadsheet,
                          icon: const Icon(Icons.table_view_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Situação',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      const [
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
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'Todos'),
                ),
                const SizedBox(height: 12),
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
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(
                            alpha: 0.10,
                          ),
                          child: const Icon(
                            Icons.pets,
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
