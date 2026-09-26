import 'package:flutter/material.dart';

import '../../../core/widgets/contextual_help.dart';
import '../../animals/services/animal_service.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../services/farmacia_service.dart';

class FarmaciaPage extends StatefulWidget {
  const FarmaciaPage({super.key});

  @override
  State<FarmaciaPage> createState() => _FarmaciaPageState();
}

class _FarmaciaPageState extends State<FarmaciaPage> {
  final _service = FarmaciaService();
  final _selection = RebanhoSelectionService.instance;
  final _animalService = AnimalService();

  List<Map<String, dynamic>> _produtos = [];
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _animais = [];
  List<Map<String, dynamic>> _alertas = [];
  bool _carregando = true;

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
    if (!mounted) return;
    setState(() => _carregando = true);
    try {
      final loteId = _selection.rebanhoSelecionadoId;
      final produtos = await _service.listarProdutos();
      final alertas = await _service.listarAlertas();
      final animais = loteId == null
          ? <Map<String, dynamic>>[]
          : await _animalService.getTodosAnimais(rebanhoId: loteId);
      final movimentos = loteId == null
          ? <Map<String, dynamic>>[]
          : await _service.listarMovimentacoes(loteId: loteId);

      if (!mounted) return;
      setState(() {
        _produtos = produtos;
        _alertas = alertas;
        _animais = animais;
        _movimentacoes = movimentos;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _mensagem(_erro(e));
    }
  }

  Future<void> _novoProduto() async {
    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _ProdutoDialog(),
    );
    if (dados == null) return;
    try {
      await _service.criarProduto(
        nome: dados['nome'],
        categoria: dados['categoria'],
        unidade: dados['unidade'],
        estoque: dados['estoque'],
        estoqueMinimo: dados['estoqueMinimo'],
        validade: dados['validade'],
        principioAtivo: dados['principioAtivo'],
        fabricante: dados['fabricante'],
        conteudoEmbalagem: dados['conteudoEmbalagem'],
        unidadeEmbalagem: dados['unidadeEmbalagem'],
        codigoLote: dados['codigoLote'],
        observacoes: dados['observacoes'],
      );
      await _carregar();
      _mensagem('Produto cadastrado.');
    } catch (e) {
      _mensagem(_erro(e));
    }
  }

  Future<void> _corrigirEstoque(Map<String, dynamic> produto) async {
    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CorrecaoEstoqueDialog(produto: produto),
    );
    if (dados == null) return;

    try {
      await _service.corrigirEstoque(
        produtoId: produto['id'].toString(),
        novoEstoque: dados['novoEstoque'] as double,
        observacoes: dados['observacoes'] as String?,
      );
      await _carregar();
      _mensagem('Estoque corrigido com sucesso.');
    } catch (e) {
      _mensagem(_erro(e));
    }
  }

  Future<void> _desativarProduto(Map<String, dynamic> produto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover produto?'),
        content: Text(
          'O produto "${produto['nome']}" será retirado do estoque ativo. '
          'O histórico de movimentações continuará preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _service.desativarProduto(produto['id'].toString());
      await _carregar();
      _mensagem('Produto removido do estoque ativo.');
    } catch (e) {
      _mensagem(_erro(e));
    }
  }

  Future<void> _movimentar(Map<String, dynamic> produto) async {
    final rebanhoId = _selection.rebanhoSelecionadoId;
    if (rebanhoId == null) {
      _mensagem('Selecione um lote antes de movimentar a farmácia.');
      return;
    }

    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MovimentoDialog(produto: produto, animais: _animais),
    );
    if (dados == null) return;

    try {
      await _service.movimentar(
        produtoId: produto['id'].toString(),
        tipo: dados['tipo'],
        quantidade: dados['quantidade'],
        loteId: rebanhoId,
        animalId: dados['animalId'],
        observacoes: dados['observacoes'],
        codigoLote: dados['codigoLote'],
        validade: dados['validade'],
        fabricante: dados['fabricante'],
      );
      await _carregar();
      _mensagem(
        dados['tipo'] == 'saida'
            ? 'Saída registrada usando FEFO.'
            : 'Entrada registrada em novo lote.',
      );
    } catch (e) {
      _mensagem(_erro(e));
    }
  }

  String _erro(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String _quantidade(Map<String, dynamic> p) {
    final unidade = (p['unidade_estoque'] ?? p['unidade'] ?? 'unidade').toString();
    return _service.formatarQuantidade(p['estoque'], unidade: unidade);
  }

  bool _baixo(Map<String, dynamic> p) {
    final estoque = double.tryParse((p['estoque'] ?? 0).toString()) ?? 0;
    final minimo = double.tryParse((p['estoque_minimo'] ?? 0).toString()) ?? 0;
    return minimo > 0 && estoque <= minimo;
  }

  @override
  Widget build(BuildContext context) {
    final rebanho = _selection.rebanhoSelecionado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmácia'),
        actions: [
          const ContextualHelpButton(
            title: 'Farmácia',
            introduction: 'Controle produtos, lotes, validade, estoque e consumo.',
            topics: [
              HelpTopic(
                title: 'FEFO',
                description: 'Nas saídas, o sistema usa primeiro o lote que vence antes.',
              ),
              HelpTopic(
                title: 'Estoque preciso',
                description: 'Controle ml, L, mg, g, unidade ou comprimido.',
              ),
              HelpTopic(
                title: 'Lotes',
                description: 'Cada entrada pode ter código, validade e fabricante próprios.',
              ),
              HelpTopic(
                title: 'Alertas',
                description: 'A tela mostra produtos que atingiram o estoque mínimo.',
              ),
            ],
          ),
          IconButton(
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : rebanho == null
              ? const _SelecioneLote()
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Text(
                        'Lote: ' + rebanho.nome,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_alertas.isNotEmpty) _AlertasCard(alertas: _alertas),
                      if (_alertas.isNotEmpty) const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _novoProduto,
                        icon: const Icon(Icons.add),
                        label: const Text('Cadastrar produto'),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Estoque da fazenda',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_produtos.isEmpty)
                        const Text('Nenhum produto cadastrado.')
                      else
                        ..._produtos.map(
                          (p) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  _baixo(p)
                                      ? Icons.warning_amber_rounded
                                      : Icons.medical_services_outlined,
                                ),
                              ),
                              title: Text(p['nome'].toString()),
                              subtitle: Text(
                                p['categoria'].toString() + ' • ' + _quantidade(p),
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Ações do produto',
                                onSelected: (acao) {
                                  switch (acao) {
                                    case 'movimentar':
                                      _movimentar(p);
                                      break;
                                    case 'corrigir':
                                      _corrigirEstoque(p);
                                      break;
                                    case 'remover':
                                      _desativarProduto(p);
                                      break;
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'movimentar',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.swap_vert_rounded),
                                      title: Text('Movimentar estoque'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'corrigir',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.edit_note_outlined),
                                      title: Text('Corrigir estoque'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'remover',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.archive_outlined),
                                      title: Text('Remover do estoque'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'Movimentações deste lote',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_movimentacoes.isEmpty)
                        const Text('Nenhuma movimentação neste lote.')
                      else
                        ..._movimentacoes.map((item) {
                          final p = item['farmacia_produtos'];
                          final l = item['farmacia_lotes'];
                          final nome = p is Map ? p['nome'].toString() : 'Produto';
                          final unidade = p is Map
                              ? (p['unidade_estoque'] ?? p['unidade'] ?? '').toString()
                              : '';
                          final codigo = l is Map ? l['codigo_lote']?.toString() : null;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              item['tipo'] == 'entrada'
                                  ? Icons.add_circle
                                  : Icons.remove_circle,
                            ),
                            title: Text(nome),
                            subtitle: Text(
                              item['tipo'].toString() +
                                  ' • ' +
                                  _service.formatarQuantidade(
                                    item['quantidade'],
                                    unidade: unidade,
                                  ) +
                                  (codigo == null || codigo.isEmpty
                                      ? ''
                                      : ' • lote ' + codigo),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _AlertasCard extends StatelessWidget {
  final List<Map<String, dynamic>> alertas;

  const _AlertasCard({required this.alertas});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notifications_active_outlined),
                SizedBox(width: 8),
                Text('Atenção', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            const SizedBox(height: 8),
            ...alertas.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ' + (a['mensagem'] ?? a['titulo'] ?? 'Alerta').toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelecioneLote extends StatelessWidget {
  const _SelecioneLote();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Selecione um lote no início para acessar a farmácia.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _ProdutoDialog extends StatefulWidget {
  const _ProdutoDialog();

  @override
  State<_ProdutoDialog> createState() => _ProdutoDialogState();
}

class _ProdutoDialogState extends State<_ProdutoDialog> {
  final nome = TextEditingController();
  final unidade = TextEditingController(text: 'ml');
  final estoque = TextEditingController(text: '0');
  final minimo = TextEditingController(text: '0');
  final principio = TextEditingController();
  final fabricante = TextEditingController();
  final conteudo = TextEditingController();
  final unidadeEmbalagem = TextEditingController(text: 'ml');
  final codigoLote = TextEditingController();
  final observacoes = TextEditingController();

  String categoria = 'vacina';
  DateTime? validade;

  @override
  void dispose() {
    nome.dispose();
    unidade.dispose();
    estoque.dispose();
    minimo.dispose();
    principio.dispose();
    fabricante.dispose();
    conteudo.dispose();
    unidadeEmbalagem.dispose();
    codigoLote.dispose();
    observacoes.dispose();
    super.dispose();
  }

  Future<void> _validade() async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: validade ?? agora,
      firstDate: agora.subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) setState(() => validade = data);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cadastrar produto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _FarmaciaSecao(titulo: '1. Identificação', descricao: 'Nome, categoria e fabricante.'),
              TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome')),
              DropdownButtonFormField<String>(
                value: categoria,
                items: const [
                  DropdownMenuItem(value: 'vacina', child: Text('Vacina')),
                  DropdownMenuItem(value: 'vermifugo', child: Text('Vermífugo')),
                  DropdownMenuItem(value: 'medicamento', child: Text('Medicamento')),
                  DropdownMenuItem(value: 'outro', child: Text('Outro')),
                ],
                onChanged: (v) => setState(() => categoria = v!),
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const _FarmaciaSecao(titulo: '2. Controle de estoque', descricao: 'Defina como a quantidade será medida.'),
              TextField(
                controller: unidade,
                decoration: const InputDecoration(
                  labelText: 'Unidade do estoque',
                  hintText: 'ml, L, mg, g, unidade, comprimido...',
                ),
              ),
              TextField(controller: principio, decoration: const InputDecoration(labelText: 'Princípio ativo')),
              TextField(controller: fabricante, decoration: const InputDecoration(labelText: 'Fabricante')),
              const _FarmaciaSecao(titulo: '3. Embalagem', descricao: 'Opcional, mas ajuda a identificar a apresentação comprada.'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: conteudo,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Conteúdo da embalagem'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unidadeEmbalagem,
                      decoration: const InputDecoration(labelText: 'Unidade'),
                    ),
                  ),
                ],
              ),
              const _FarmaciaSecao(titulo: '4. Estoque inicial', descricao: 'Informe quanto você possui agora e o limite para alerta.'),
              TextField(
                controller: estoque,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Estoque inicial'),
              ),
              TextField(
                controller: minimo,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Estoque mínimo'),
              ),
              const _FarmaciaSecao(titulo: '5. Lote e validade', descricao: 'Esses dados alimentam o FEFO.'),
              TextField(controller: codigoLote, decoration: const InputDecoration(labelText: 'Lote inicial')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  validade == null ? 'Validade: não informada' : 'Validade: ' + _formatarData(validade!),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _validade,
              ),
              TextField(
                controller: observacoes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observações'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final e = double.tryParse(estoque.text.replaceAll(',', '.')) ?? 0;
              final m = double.tryParse(minimo.text.replaceAll(',', '.')) ?? 0;
              final c = double.tryParse(conteudo.text.replaceAll(',', '.'));
              if (nome.text.trim().isEmpty || e < 0 || m < 0 || (c != null && c <= 0)) return;
              Navigator.pop(context, {
                'nome': nome.text,
                'categoria': categoria,
                'unidade': unidade.text,
                'estoque': e,
                'estoqueMinimo': m,
                'principioAtivo': principio.text,
                'fabricante': fabricante.text,
                'conteudoEmbalagem': c,
                'unidadeEmbalagem': unidadeEmbalagem.text,
                'codigoLote': codigoLote.text,
                'validade': validade,
                'observacoes': observacoes.text,
              });
            },
            child: const Text('Cadastrar'),
          ),
        ],
      );
}


class _CorrecaoEstoqueDialog extends StatefulWidget {
  final Map<String, dynamic> produto;

  const _CorrecaoEstoqueDialog({required this.produto});

  @override
  State<_CorrecaoEstoqueDialog> createState() => _CorrecaoEstoqueDialogState();
}

class _CorrecaoEstoqueDialogState extends State<_CorrecaoEstoqueDialog> {
  late final TextEditingController estoque;
  final observacoes = TextEditingController();

  @override
  void initState() {
    super.initState();
    estoque = TextEditingController(
      text: widget.produto['estoque']?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    estoque.dispose();
    observacoes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unidade = (
      widget.produto['unidade_estoque'] ??
      widget.produto['unidade'] ??
      'unidade'
    ).toString();

    return AlertDialog(
      title: const Text('Corrigir estoque'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.produto['nome'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text('Saldo atual: ${widget.produto['estoque']} $unidade'),
            const SizedBox(height: 16),
            TextField(
              controller: estoque,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Novo saldo',
                suffixText: unidade,
                helperText: 'A diferença será registrada como ajuste e manterá os lotes sincronizados.',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: observacoes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo da correção',
                hintText: 'Ex.: cadastrei 500 ml, mas eram 50 ml',
              ),
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
            final valor = double.tryParse(estoque.text.replaceAll(',', '.'));
            if (valor == null || valor < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Informe um saldo válido.')),
              );
              return;
            }
            Navigator.pop(context, {
              'novoEstoque': valor,
              'observacoes': observacoes.text.trim(),
            });
          },
          child: const Text('Corrigir estoque'),
        ),
      ],
    );
  }
}

class _FarmaciaSecao extends StatelessWidget {
  final String titulo;
  final String descricao;

  const _FarmaciaSecao({
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(
            descricao,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MovimentoDialog extends StatefulWidget {
  final Map<String, dynamic> produto;
  final List<Map<String, dynamic>> animais;

  const _MovimentoDialog({required this.produto, required this.animais});

  @override
  State<_MovimentoDialog> createState() => _MovimentoDialogState();
}

class _MovimentoDialogState extends State<_MovimentoDialog> {
  String tipo = 'saida';
  final quantidade = TextEditingController(text: '1');
  final codigoLote = TextEditingController();
  final fabricante = TextEditingController();
  final observacoes = TextEditingController();
  String? animalId;
  DateTime? validade;

  @override
  void dispose() {
    quantidade.dispose();
    codigoLote.dispose();
    fabricante.dispose();
    observacoes.dispose();
    super.dispose();
  }

  Future<void> _validade() async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: validade ?? agora,
      firstDate: agora.subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) setState(() => validade = data);
  }

  @override
  Widget build(BuildContext context) {
    final unidade = (widget.produto['unidade_estoque'] ?? widget.produto['unidade'] ?? 'unidade').toString();

    return AlertDialog(
      title: Text(widget.produto['nome'].toString()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Estoque atual: ' + widget.produto['estoque'].toString() + ' ' + unidade,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: tipo,
              items: const [
                DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
                DropdownMenuItem(value: 'saida', child: Text('Saída')),
              ],
              onChanged: (v) => setState(() => tipo = v!),
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            TextField(
              controller: quantidade,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Quantidade', suffixText: unidade),
            ),
            if (tipo == 'saida')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'FEFO ativo: a saída será retirada primeiro do lote que vence antes.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            DropdownButtonFormField<String?>(
              value: animalId,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Lote inteiro')),
                ...widget.animais.map(
                  (a) => DropdownMenuItem<String?>(
                    value: a['id'].toString(),
                    child: Text('Brinco ' + a['brinco'].toString()),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => animalId = v),
              decoration: const InputDecoration(labelText: 'Animal (opcional)'),
            ),
            if (tipo == 'entrada') ...[
              TextField(controller: codigoLote, decoration: const InputDecoration(labelText: 'Código do lote')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  validade == null ? 'Validade: não informada' : 'Validade: ' + _formatarData(validade!),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _validade,
              ),
              TextField(controller: fabricante, decoration: const InputDecoration(labelText: 'Fabricante')),
            ],
            TextField(
              controller: observacoes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final q = double.tryParse(quantidade.text.replaceAll(',', '.'));
            if (q == null || q <= 0) return;
            Navigator.pop(context, {
              'tipo': tipo,
              'quantidade': q,
              'animalId': animalId,
              'codigoLote': codigoLote.text,
              'validade': validade,
              'fabricante': fabricante.text,
              'observacoes': observacoes.text,
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

String _formatarData(DateTime data) {
  final d = data.day.toString().padLeft(2, '0');
  final m = data.month.toString().padLeft(2, '0');
  return d + '/' + m + '/' + data.year.toString();
}
