import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../services/financeiro_service.dart';

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  final _service = FinanceiroService();
  final _selection = RebanhoSelectionService.instance;

  List<Map<String, dynamic>> _registros = [];
  bool _carregando = true;
  Map<String, double> _resumo = {'receitas': 0, 'despesas': 0, 'saldo': 0};

  @override
  void initState() {
    super.initState();
    _selection.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    _selection.removeListener(_carregar);
    super.dispose();
  }

  Future<void> _carregar() async {
    final loteId = _selection.rebanhoSelecionadoId;
    if (loteId == null) {
      if (mounted) {
        setState(() {
          _registros = [];
          _resumo = {'receitas': 0, 'despesas': 0, 'saldo': 0};
          _carregando = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _carregando = true);

    try {
      final registros = await _service.listar(loteId: loteId);
      final resumo = await _service.resumo(loteId: loteId);
      if (!mounted) return;
      setState(() {
        _registros = registros;
        _resumo = resumo;
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
      builder: (_) => const _LancamentoDialog(),
    );
    if (dados == null) return;
    final loteId = _selection.rebanhoSelecionadoId;
    if (loteId == null) return;

    try {
      await _service.criar(
        tipo: dados['tipo'],
        categoria: dados['categoria'],
        descricao: dados['descricao'],
        valor: dados['valor'],
        data: dados['data'],
        loteId: loteId,
        observacoes: dados['observacoes'],
      );
      await _carregar();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _msg(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _moeda(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final lote = _selection.rebanhoSelecionado;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Despesas e lucro'),
        actions: [
          IconButton(
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: lote == null || _carregando ? null : _novo,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Lançamento'),
      ),
      body: lote == null
          ? const Center(
              child: Text(
                'Selecione um lote no início para acessar o financeiro.',
              ),
            )
          : _carregando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Text(
                        'Lote: ${lote.nome}',
                        style: const TextStyle(
                          fontSize: 18,
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
                          'Nenhum lançamento neste lote.',
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
  const _LancamentoDialog();

  @override
  State<_LancamentoDialog> createState() => _LancamentoDialogState();
}

class _LancamentoDialogState extends State<_LancamentoDialog> {
  String tipo = 'despesa';
  final categoria = TextEditingController();
  final descricao = TextEditingController();
  final valor = TextEditingController();
  final observacoes = TextEditingController();

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
                'data': DateTime.now(),
                'observacoes': observacoes.text,
              });
            },
            child: const Text('Salvar'),
          ),
        ],
      );
}
