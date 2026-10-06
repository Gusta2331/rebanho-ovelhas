import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../services/additional_report_service.dart';

class FarmaciaReportPage extends StatefulWidget {
  final VoidCallback onBack;
  const FarmaciaReportPage({super.key, required this.onBack});
  @override
  State<FarmaciaReportPage> createState() => _FarmaciaReportPageState();
}

class _FarmaciaReportPageState extends State<FarmaciaReportPage> {
  final _service = AdditionalReportService();
  final _search = TextEditingController();
  bool _loading = true, _generating = false;
  String? _error, _category;
  List<Map<String, dynamic>> _all = [], _items = [];
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');
      final farm = await SupabaseService.client
          .from('fazendas').select('id')
          .eq('proprietario_id', user.id).eq('ativo', true).maybeSingle();
      final farmId = farm?['id']?.toString();
      if (farmId == null || farmId.isEmpty) {
        throw Exception('Nenhuma fazenda ativa foi encontrada.');
      }
      final result = await SupabaseService.client
          .from('farmacia_produtos')
          .select('id,nome,categoria,unidade,estoque,estoque_minimo,validade,principio_ativo,fabricante')
          .eq('fazenda_id', farmId).eq('ativo', true).order('nome');
      _all = List<Map<String, dynamic>>.from(result);
      _filter();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _filter() {
    final text = _search.text.trim().toLowerCase();
    final list = _all.where((item) {
      if (_category != null && item['categoria']?.toString() != _category) {
        return false;
      }
      if (text.isEmpty) return true;
      return [item['nome'], item['categoria'], item['principio_ativo'], item['fabricante']]
          .any((v) => v?.toString().toLowerCase().contains(text) == true);
    }).toList();
    if (mounted) setState(() => _items = list);
  }

  List<Map<String, dynamic>> get _selectedItems =>
      _items.where((r) => _selectedIds.contains(r['id'].toString())).toList();

  void _toggle(Map<String, dynamic> item) {
    final id = item['id'].toString();
    setState(() {
      if (_selectedIds.contains(id)) { _selectedIds.remove(id); }
      else { _selectedIds.add(id); }
    });
  }

  void _selectAll() =>
      setState(() => _selectedIds.addAll(_items.map((e) => e['id'].toString())));

  void _clearSelection() => setState(() => _selectedIds.clear());

  void _clearFilters() {
    _search.clear();
    setState(() => _category = null);
    _filter();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _all.map((e) => e['categoria']?.toString())
        .whereType<String>().where((e) => e.isNotEmpty).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          AppAssetIcon(assetPath: 'assets/images/icon_farmacia.png', size: 26),
          SizedBox(width: 8), Text('Relatório de farmácia'),
        ]),
        actions: [
          IconButton(
            onPressed: _loading || _generating || _selectedItems.isEmpty ? null : _chooseFormat,
            icon: _generating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
          ),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
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
                          labelText: 'Buscar produto',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty ? null : IconButton(
                            onPressed: _search.clear,
                            icon: const Icon(Icons.clear_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'Categoria'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todas as categorias')),
                          ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: (value) { setState(() => _category = value); _filter(); },
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        TextButton.icon(
                          onPressed: _items.isEmpty ? null : _selectAll,
                          icon: const Icon(Icons.select_all_rounded),
                          label: const Text('Selecionar todos'),
                        ),
                        TextButton(
                          onPressed: _selectedIds.isEmpty ? null : _clearSelection,
                          child: const Text('Limpar'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _category == null && _search.text.isEmpty ? null : _clearFilters,
                          child: const Text('Filtros'),
                        ),
                      ]),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _selectedItems.length.toString() + ' selecionado(s) de ' + _items.length.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_items.isEmpty)
                        const Card(child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(child: Text('Nenhum produto encontrado.')),
                        ))
                      else
                        ..._items.map(_card),
                    ],
                  ),
                ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final id = item['id'].toString();
    final estoque = _number(item['estoque']);
    final minimo = _number(item['estoque_minimo']);
    final unidade = item['unidade']?.toString() ?? 'unidade';
    final alerta = estoque <= minimo;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: _selectedIds.contains(id),
        onChanged: (_) => _toggle(item),
        secondary: const AppAssetIcon(assetPath: 'assets/images/icon_farmacia.png', size: 38),
        title: Text(item['nome']?.toString() ?? 'Produto', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          (item['categoria'] ?? 'Sem categoria').toString() +
          ' - Estoque: ' + _format(estoque) + ' ' + unidade +
          (alerta ? ' - Estoque baixo' : ''),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
    if (format != null && mounted) await _generate(format);
  }

  Future<void> _generate(String format) async {
    setState(() => _generating = true);
    try {
      final rows = _selectedItems.map((r) => [
        r['nome']?.toString() ?? 'Não informado',
        r['categoria']?.toString() ?? 'Não informada',
        (_format(_number(r['estoque'])) + ' ' + (r['unidade'] ?? '')).trim(),
        (_format(_number(r['estoque_minimo'])) + ' ' + (r['unidade'] ?? '')).trim(),
        r['validade']?.toString() ?? 'Não informada',
        r['fabricante']?.toString() ?? 'Não informado',
      ]).toList();
      const headers = ['Produto', 'Categoria', 'Estoque', 'Mínimo', 'Validade', 'Fabricante'];
      final bytes = format == 'pdf'
          ? await _service.gerarPdf(
              title: 'Relatório de farmácia',
              subtitle: 'Produtos selecionados',
              headers: headers, rows: rows,
            )
          : await _service.gerarExcel(
              title: 'Relatório de farmácia',
              subtitle: 'Produtos selecionados',
              headers: headers, rows: rows,
            );
      final mime = format == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime)],
        fileNameOverrides: [format == 'pdf' ? 'ovigestao_relatorio_farmacia.pdf' : 'ovigestao_relatorio_farmacia.xlsx'],
        title: 'Relatório de farmácia',
        subject: 'Relatório de farmácia - Fazenda Baixinha',
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((format == 'pdf' ? 'PDF' : 'Excel') + ' gerado com ' + _selectedItems.length.toString() + ' produto(s).')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o relatório: ' + e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar novamente')),
      ]),
    ),
  );

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  String _format(double value) => value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
}
