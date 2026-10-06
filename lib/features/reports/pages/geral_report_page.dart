import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../services/additional_report_service.dart';

class GeralReportPage extends StatefulWidget {
  final VoidCallback onBack;
  const GeralReportPage({super.key, required this.onBack});
  @override
  State<GeralReportPage> createState() => _GeralReportPageState();
}

class _GeralReportPageState extends State<GeralReportPage> {
  final _service = AdditionalReportService();
  bool _loading = true, _generating = false;
  String? _error;
  final Set<String> _selectedIds = <String>{};
  final List<Map<String, String>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
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

      final animais = await SupabaseService.client
          .from('animais').select('id,status,sexo').eq('fazenda_id', farmId);
      final produtos = await SupabaseService.client
          .from('farmacia_produtos').select('id,estoque,estoque_minimo')
          .eq('fazenda_id', farmId).eq('ativo', true);
      final financeiro = await SupabaseService.client
          .from('financeiro_lancamentos').select('tipo,valor').eq('fazenda_id', farmId);
      final reproducoes = await SupabaseService.client
          .from('reproducoes').select('id').eq('fazenda_id', farmId);
      final manejos = await SupabaseService.client
          .from('manejos').select('id').eq('fazenda_id', farmId);

      final ativos = animais.where((e) => e['status'] == 'ativo').length;
      final receitas = financeiro.where((e) => e['tipo'] == 'receita').fold<double>(
        0, (s, e) => s + _number(e['valor']));
      final despesas = financeiro.where((e) => e['tipo'] != 'receita').fold<double>(
        0, (s, e) => s + _number(e['valor']));
      final baixo = produtos.where((e) =>
          _number(e['estoque']) <= _number(e['estoque_minimo'])).length;

      _items
        ..clear()
        ..addAll([
          {
            'id': 'rebanho',
            'titulo': 'Rebanho',
            'valor': ativos.toString() + ' animal(is) ativo(s)',
          },
          {
            'id': 'farmacia',
            'titulo': 'Farmácia',
            'valor': produtos.length.toString() +
                ' produto(s), ' +
                baixo.toString() +
                ' em estoque baixo',
          },
          {
            'id': 'financeiro',
            'titulo': 'Financeiro',
            'valor': 'Receitas R\$ ' + _money(receitas) +
                ' - Despesas R\$ ' + _money(despesas) +
                ' - Saldo R\$ ' + _money(receitas - despesas),
          },
          {
            'id': 'reproducao',
            'titulo': 'Reprodução',
            'valor': reproducoes.length.toString() + ' registro(s)',
          },
          {
            'id': 'manejo',
            'titulo': 'Manejo',
            'valor': manejos.length.toString() + ' registro(s)',
          },
        ]);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) _selectedIds.remove(id);
      else _selectedIds.add(id);
    });
  }

  void _selectAll() =>
      setState(() => _selectedIds.addAll(_items.map((e) => e['id']!)));

  void _clearSelection() => setState(() => _selectedIds.clear());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          AppAssetIcon(assetPath: 'assets/images/icon_relatorios.png', size: 26),
          SizedBox(width: 8), Text('Relatório geral'),
        ]),
        actions: [
          IconButton(
            onPressed: _loading || _generating || _selectedIds.isEmpty ? null : _chooseFormat,
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    Row(children: [
                      TextButton.icon(
                        onPressed: _selectAll,
                        icon: const Icon(Icons.select_all_rounded),
                        label: const Text('Selecionar todos'),
                      ),
                      TextButton(
                        onPressed: _selectedIds.isEmpty ? null : _clearSelection,
                        child: const Text('Limpar'),
                      ),
                    ]),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _selectedIds.length.toString() +
                              ' bloco(s) selecionado(s) de ' +
                              _items.length.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._items.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: CheckboxListTile(
                        value: _selectedIds.contains(item['id']),
                        onChanged: (_) => _toggle(item['id']!),
                        secondary: const AppAssetIcon(
                          assetPath: 'assets/images/icon_relatorios.png',
                          size: 38,
                        ),
                        title: Text(item['titulo']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(item['valor']!),
                      ),
                    )),
                  ],
                ),
    );
  }

  Future<void> _chooseFormat() async {
    if (_selectedIds.isEmpty || _generating) return;
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Escolha o formato')),
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('PDF'), onTap: () => Navigator.pop(ctx, 'pdf')),
          ListTile(leading: const Icon(Icons.table_view_outlined), title: const Text('Excel'), onTap: () => Navigator.pop(ctx, 'excel')),
        ]),
      ),
    );
    if (format != null && mounted) await _generate(format);
  }

  Future<void> _generate(String format) async {
    setState(() => _generating = true);
    try {
      final rows = _items
          .where((e) => _selectedIds.contains(e['id']))
          .map((e) => [e['titulo']!, e['valor']!])
          .toList();
      const headers = ['Área', 'Resumo'];
      final bytes = format == 'pdf'
          ? await _service.gerarPdf(
              title: 'Relatório geral',
              subtitle: 'Blocos selecionados da Fazenda Baixinha',
              headers: headers, rows: rows,
            )
          : await _service.gerarExcel(
              title: 'Relatório geral',
              subtitle: 'Blocos selecionados da Fazenda Baixinha',
              headers: headers, rows: rows,
            );
      final mime = format == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime)],
        fileNameOverrides: [
          format == 'pdf'
              ? 'ovigestao_relatorio_geral.pdf'
              : 'ovigestao_relatorio_geral.xlsx',
        ],
        title: 'Relatório geral',
        subject: 'Relatório geral - Fazenda Baixinha',
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (format == 'pdf' ? 'PDF' : 'Excel') +
                  ' gerado com ' +
                  _selectedIds.length.toString() +
                  ' bloco(s).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível gerar o relatório: ' +
                e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
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
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      ]),
    ),
  );

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  String _money(double value) => value.toStringAsFixed(2).replaceAll('.', ',');
}
