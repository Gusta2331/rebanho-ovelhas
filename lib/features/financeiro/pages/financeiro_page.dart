import 'package:flutter/material.dart';

import '../../../core/widgets/contextual_help.dart';
import '../../../core/theme/app_theme.dart';
import '../../flock/services/rebanho_service.dart';
import '../services/financeiro_service.dart';

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  final _service = FinanceiroService();
  final _rebanhoService = RebanhoService();

  List<Map<String, dynamic>> _registros = [];
  List<Map<String, dynamic>> _lotes = [];
  String? _filtroLoteId;
  bool _carregando = true;
  Map<String, double> _resumo = {'receitas': 0, 'despesas': 0, 'saldo': 0};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) setState(() => _carregando = true);

    try {
      final resultados = await Future.wait([
        _service.listar(loteId: _filtroLoteId),
        _service.resumo(loteId: _filtroLoteId),
        _rebanhoService.getRebanhos(),
      ]);
      if (!mounted) return;
      setState(() {
        _registros = List<Map<String, dynamic>>.from(resultados[0] as List);
        _resumo = Map<String, double>.from(resultados[1] as Map);
        _lotes = List<Map<String, dynamic>>.from(resultados[2] as List);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _novo() async {
    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _LancamentoDialog(lotes: _lotes, loteIdInicial: _filtroLoteId),
    );
    if (dados == null) return;

    try {
      await _service.criar(
        tipo: dados['tipo'],
        categoria: dados['categoria'],
        descricao: dados['descricao'],
        valor: dados['valor'],
        data: dados['data'],
        loteId: dados['loteId'] as String?,
        observacoes: dados['observacoes'],
      );
      await _carregar();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _msg(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _moeda(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final loteSelecionado = _lotes.cast<Map<String, dynamic>?>().firstWhere(
      (lote) => lote?['id']?.toString() == _filtroLoteId,
      orElse: () => null,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Despesas e lucro'),
        actions: [
          const ContextualHelpButton(
            title: 'Despesas e lucro',
            introduction: 'Acompanhe receitas, despesas e saldo. A tela começa mostrando toda a fazenda e também permite filtrar por lote.',
            topics: [
              HelpTopic(
                title: 'Lançamento',
                description: 'Registre uma receita ou despesa com categoria, descrição, valor e data. Associe um lote se quiser analisar aquele grupo separadamente.',
              ),
              HelpTopic(
                title: 'Toda a fazenda',
                description: 'Inclui os lançamentos gerais e os associados aos lotes. Use esta visão para acompanhar o resultado consolidado.',
              ),
              HelpTopic(
                title: 'Filtro por lote',
                description: 'Mostra somente lançamentos associados ao lote escolhido; lançamentos gerais da fazenda não entram nesse filtro.',
              ),
              HelpTopic(
                title: 'Saldo',
                description: 'O saldo é calculado como receitas menos despesas registradas no período disponível.',
              ),
            ],
          ),
          IconButton(
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _carregando ? null : _novo,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Lançamento'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  DropdownButtonFormField<String?>(
                    value: _filtroLoteId,
                    decoration: const InputDecoration(
                      labelText: 'Mostrar financeiro de',
                      prefixIcon: Icon(Icons.filter_alt_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toda a fazenda'),
                      ),
                      ..._lotes.map(
                        (lote) => DropdownMenuItem<String?>(
                          value: lote['id'].toString(),
                          child: Text(lote['nome']?.toString() ?? 'Lote'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _filtroLoteId = value);
                      _carregar();
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _filtroLoteId == null
                        ? 'Visão geral: todos os lotes e lançamentos da fazenda'
                        : 'Lote: ${loteSelecionado?['nome'] ?? 'selecionado'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth - 16) / 3,
                            child: _ResumoCard(
                              titulo: 'Receitas',
                              valor: _moeda(_resumo['receitas']!),
                              icone: Icons.trending_up,
                            ),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 16) / 3,
                            child: _ResumoCard(
                              titulo: 'Despesas',
                              valor: _moeda(_resumo['despesas']!),
                              icone: Icons.trending_down,
                            ),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 16) / 3,
                            child: _ResumoCard(
                              titulo: 'Saldo',
                              valor: _moeda(_resumo['saldo']!),
                              icone: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_registros.isEmpty)
                    const Text(
                      'Nenhum lançamento neste período.',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    ..._registros.map(
                      (item) => Card(
                        child: ListTile(
                          leading: Icon(
                            item['tipo'] == 'receita'
                                ? Icons.add_circle
                                : Icons.remove_circle,
                          ),
                          title: Text(item['descricao'].toString()),
                          subtitle: Text(
                            '${item['categoria']} • ${item['data']}',
                          ),
                          trailing: Text(
                            _moeda((item['valor'] as num).toDouble()),
                            style: const TextStyle(fontWeight: FontWeight.bold),
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

class _ResumoCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;

  const _ResumoCard({
    required this.titulo,
    required this.valor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icone, color: AppTheme.primaryColor),
          const SizedBox(height: 5),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LancamentoDialog extends StatefulWidget {
  const _LancamentoDialog({required this.lotes, this.loteIdInicial});

  final List<Map<String, dynamic>> lotes;
  final String? loteIdInicial;

  @override
  State<_LancamentoDialog> createState() => _LancamentoDialogState();
}

class _LancamentoDialogState extends State<_LancamentoDialog> {
  String tipo = 'despesa';
  String? loteId;
  DateTime data = DateTime.now();
  final categoria = TextEditingController();
  final descricao = TextEditingController();
  final valor = TextEditingController();
  final observacoes = TextEditingController();

  @override
  void initState() {
    super.initState();
    loteId = widget.loteIdInicial;
  }

  @override
  void dispose() {
    categoria.dispose();
    descricao.dispose();
    valor.dispose();
    observacoes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Novo lançamento'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: tipo,
            items: const [
              DropdownMenuItem(value: 'despesa', child: Text('Despesa')),
              DropdownMenuItem(value: 'receita', child: Text('Receita')),
            ],
            onChanged: (v) => setState(() => tipo = v!),
            decoration: const InputDecoration(labelText: 'Tipo'),
          ),
          TextField(
            controller: categoria,
            decoration: const InputDecoration(labelText: 'Categoria'),
          ),
          TextField(
            controller: descricao,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          TextField(
            controller: valor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor'),
          ),
          DropdownButtonFormField<String?>(
            value: loteId,
            decoration: const InputDecoration(labelText: 'Vincular a lote'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Fazenda toda'),
              ),
              ...widget.lotes.map(
                (lote) => DropdownMenuItem<String?>(
                  value: lote['id'].toString(),
                  child: Text(lote['nome']?.toString() ?? 'Lote'),
                ),
              ),
            ],
            onChanged: (value) => setState(() => loteId = value),
          ),
          InkWell(
            onTap: () async {
              final selecionada = await showDatePicker(
                context: context,
                initialDate: data,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                locale: const Locale('pt', 'BR'),
              );
              if (selecionada != null) setState(() => data = selecionada);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                data.day.toString().padLeft(2, '0') +
                    '/' +
                    data.month.toString().padLeft(2, '0') +
                    '/' +
                    data.year.toString(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: observacoes,
            decoration: const InputDecoration(labelText: 'Observações'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          final v = double.tryParse(valor.text.replaceAll(',', '.'));
          if (v == null ||
              v <= 0 ||
              categoria.text.trim().isEmpty ||
              descricao.text.trim().isEmpty) {
            return;
          }
          Navigator.pop(context, {
            'tipo': tipo,
            'categoria': categoria.text,
            'descricao': descricao.text,
            'valor': v,
            'data': data,
            'loteId': loteId,
            'observacoes': observacoes.text,
          });
        },
        child: const Text('Salvar'),
      ),
    ],
  );
}
