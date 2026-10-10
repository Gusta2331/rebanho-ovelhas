import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../services/additional_report_service.dart';
import '../widgets/report_period.dart';

class FarmaciaReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const FarmaciaReportPage({super.key, required this.onBack});

  @override
  State<FarmaciaReportPage> createState() => _FarmaciaReportPageState();
}

class _FarmaciaReportPageState extends State<FarmaciaReportPage> {
  final _service = AdditionalReportService();
  final _search = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  String? _error;
  String? _category;

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _items = [];
  final Set<String> _selectedIds = <String>{};
  ReportPeriod _period = const ReportPeriod.all();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.removeListener(_filter);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedIds.clear();
    });

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      final farm = await SupabaseService.client
          .from('fazendas')
          .select('id')
          .eq('proprietario_id', user.id)
          .eq('ativo', true)
          .maybeSingle();

      final farmId = farm?['id']?.toString();
      if (farmId == null || farmId.isEmpty) {
        throw Exception('Nenhuma fazenda ativa foi encontrada.');
      }

      final result = await SupabaseService.client
          .from('farmacia_movimentacoes')
          .select(
            'id,tipo,quantidade,data,observacoes,produto_id,'
            'farmacia_produtos(nome,categoria,unidade,unidade_estoque),'
            'farmacia_lotes(codigo_lote,validade),'
            'animais(brinco,nome)',
          )
          .eq('fazenda_id', farmId)
          .order('data', ascending: false)
          .order('created_at', ascending: false);

      _all = List<Map<String, dynamic>>.from(result);
      _filter();

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _filter() {
    final text = _search.text.trim().toLowerCase();
    final range = _period.range();

    final list = _all.where((item) {
      if (_category != null && _category!.isNotEmpty) {
        final produto = item['farmacia_produtos'];
        final categoria = produto is Map
            ? produto['categoria']?.toString()
            : null;
        if (categoria != _category) return false;
      }

      final date = DateTime.tryParse(item['data']?.toString() ?? '');
      if (range != null &&
          (date == null ||
              date.isBefore(range.$1) ||
              date.isAfter(range.$2))) {
        return false;
      }

      if (text.isEmpty) return true;

      final produto = item['farmacia_produtos'];
      final lote = item['farmacia_lotes'];
      final animal = item['animais'];

      final searchable = <String?>[
        produto is Map ? produto['nome']?.toString() : null,
        produto is Map ? produto['categoria']?.toString() : null,
        item['tipo']?.toString(),
        item['observacoes']?.toString(),
        lote is Map ? lote['codigo_lote']?.toString() : null,
        animal is Map ? animal['brinco']?.toString() : null,
        animal is Map ? animal['nome']?.toString() : null,
      ];

      return searchable.any(
        (value) => value?.toLowerCase().contains(text) == true,
      );
    }).toList();

    if (mounted) {
      setState(() => _items = list);
    }
  }

  List<Map<String, dynamic>> get _selectedItems => _items
      .where((item) => _selectedIds.contains(item['id'].toString()))
      .toList();

  void _toggle(Map<String, dynamic> item) {
    final id = item['id'].toString();

    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_items.map((item) => item['id'].toString()));
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  void _applyPeriod(ReportPeriod value) {
    setState(() {
      _period = value;
      _selectedIds.clear();
    });
    _filter();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _category = null;
      _period = const ReportPeriod.all();
      _selectedIds.clear();
    });
    _filter();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _all
        .map((item) {
          final produto = item['farmacia_produtos'];
          return produto is Map ? produto['categoria']?.toString() : null;
        })
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Row(
          children: [
            AppAssetIcon(
              assetPath: 'assets/images/icon_farmacia.png',
              size: 26,
            ),
            SizedBox(width: 8),
            Expanded(child: Text('Relatório de farmácia', maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            onPressed:
                _loading || _generating || _selectedItems.isEmpty
                    ? null
                    : _chooseFormat,
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [
                      TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          labelText: 'Buscar movimentação',
                          hintText: 'Produto, lote, animal ou observação',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _search.clear,
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ReportPeriodCard(
                        value: _period,
                        onChanged: _applyPeriod,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todas as categorias'),
                          ),
                          ...categories.map(
                            (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _category = value;
                            _selectedIds.clear();
                          });
                          _filter();
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _items.isEmpty ? null : _selectAll,
                            icon: const Icon(Icons.select_all_rounded),
                            label: const Text('Selecionar todos'),
                          ),
                          TextButton(
                            onPressed: _selectedIds.isEmpty
                                ? null
                                : _clearSelection,
                            child: const Text('Limpar'),
                          ),
                          TextButton(
                            onPressed: _category == null &&
                                    _search.text.isEmpty &&
                                    _period.type == ReportPeriodType.all
                                ? null
                                : _clearFilters,
                            child: const Text('Filtros'),
                          ),
                        ],
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _selectedItems.length.toString() +
                                ' selecionada(s) de ' +
                                _items.length.toString() +
                                ' movimentação(ões)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_items.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(
                              child: Text(
                                'Nenhuma movimentação encontrada no período.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._items.map(_card),
                    ],
                  ),
                ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final produto = item['farmacia_produtos'];
    final lote = item['farmacia_lotes'];
    final animal = item['animais'];

    final nome = produto is Map
        ? produto['nome']?.toString() ?? 'Produto'
        : 'Produto';
    final categoria = produto is Map
        ? produto['categoria']?.toString() ?? 'Sem categoria'
        : 'Sem categoria';
    final unidade = produto is Map
        ? (produto['unidade_estoque'] ?? produto['unidade'] ?? '').toString()
        : '';
    final codigoLote = lote is Map
        ? lote['codigo_lote']?.toString()
        : null;
    final brinco = animal is Map ? animal['brinco']?.toString() : null;
    final data = _date(item['data']);
    final entrada = item['tipo']?.toString() == 'entrada';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: _selectedIds.contains(item['id'].toString()),
        onChanged: (_) => _toggle(item),
        secondary: AppAssetIcon(
          assetPath: 'assets/images/icon_farmacia.png',
          size: 38,
        ),
        title: Text(
          nome,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          (entrada ? 'Entrada' : 'Saída') +
              ' • ' +
              data +
              ' • ' +
              _format(_number(item['quantidade'])) +
              (unidade.isEmpty ? '' : ' ' + unidade) +
              ' • ' +
              categoria +
              (codigoLote == null || codigoLote.isEmpty
                  ? ''
                  : ' • Lote ' + codigoLote) +
              (brinco == null || brinco.isEmpty
                  ? ''
                  : ' • Animal ' + brinco),
        ),
      ),
    );
  }

  Future<void> _chooseFormat() async {
    if (_selectedItems.isEmpty || _generating) return;

    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Escolha o formato')),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('Excel'),
              onTap: () => Navigator.pop(ctx, 'excel'),
            ),
          ],
        ),
      ),
    );

    if (format != null && mounted) {
      await _generate(format);
    }
  }

  Future<void> _generate(String format) async {
    setState(() => _generating = true);

    try {
      final rows = _selectedItems.map((item) {
        final produto = item['farmacia_produtos'];
        final lote = item['farmacia_lotes'];
        final animal = item['animais'];

        final unidade = produto is Map
            ? (produto['unidade_estoque'] ?? produto['unidade'] ?? '').toString()
            : '';
        final nome = produto is Map
            ? produto['nome']?.toString() ?? 'Não informado'
            : 'Não informado';
        final categoria = produto is Map
            ? produto['categoria']?.toString() ?? 'Não informada'
            : 'Não informada';
        final codigoLote = lote is Map
            ? lote['codigo_lote']?.toString() ?? 'Não informado'
            : 'Não informado';
        final animalText = animal is Map
            ? [
                animal['brinco']?.toString(),
                animal['nome']?.toString(),
              ].where((value) => value != null && value.trim().isNotEmpty).join(' - ')
            : 'Não identificado';

        return [
          _date(item['data']),
          item['tipo']?.toString() == 'entrada' ? 'Entrada' : 'Saída',
          nome,
          categoria,
          (_format(_number(item['quantidade'])) +
                  (unidade.isEmpty ? '' : ' ' + unidade))
              .trim(),
          codigoLote,
          animalText.isEmpty ? 'Não identificado' : animalText,
          item['observacoes']?.toString() ?? '',
        ];
      }).toList();

      const headers = [
        'Data',
        'Tipo',
        'Produto',
        'Categoria',
        'Quantidade',
        'Lote',
        'Animal',
        'Observações',
      ];

      final subtitle =
          'Período: ' + _period.label + ' - movimentações selecionadas';

      final bytes = format == 'pdf'
          ? await _service.gerarPdf(
              title: 'Relatório de farmácia',
              subtitle: subtitle,
              headers: headers,
              rows: rows,
            )
          : await _service.gerarExcel(
              title: 'Relatório de farmácia',
              subtitle: subtitle,
              headers: headers,
              rows: rows,
            );

      final mime = format == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mime)],
          fileNameOverrides: [
            format == 'pdf'
                ? 'ovigestao_relatorio_farmacia.pdf'
                : 'ovigestao_relatorio_farmacia.xlsx',
          ],
          title: 'Relatório de farmácia',
          subject: 'Relatório de farmácia - Fazenda Baixinha',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (format == 'pdf' ? 'PDF' : 'Excel') +
                  ' gerado com ' +
                  _selectedItems.length.toString() +
                  ' movimentação(ões).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível gerar o relatório: ' +
                  e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
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

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Não informada';
    return date.day.toString().padLeft(2, '0') +
        '/' +
        date.month.toString().padLeft(2, '0') +
        '/' +
        date.year.toString();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  String _format(double value) {
    return value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }
}
