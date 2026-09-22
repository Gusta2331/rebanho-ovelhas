import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
      final animais = loteId == null
          ? <Map<String, dynamic>>[]
          : await _animalService.getAnimaisAtivos(rebanhoId: loteId);
      final movimentos = loteId == null
          ? <Map<String, dynamic>>[]
          : await _service.listarMovimentacoes(loteId: loteId);
      if (!mounted) return;
      setState(() {
        _produtos = produtos;
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
      builder: (_) => _ProdutoDialog(),
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
      );
      await _carregar();
      _mensagem('Produto cadastrado.');
    } catch (e) {
      _mensagem(_erro(e));
    }
  }

  Future<void> _movimentar(Map<String, dynamic> produto) async {
    final loteId = _selection.rebanhoSelecionadoId;
    if (loteId == null) {
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
        loteId: loteId,
        animalId: dados['animalId'],
        observacoes: dados['observacoes'],
      );
      await _carregar();
      _mensagem('Movimentação registrada.');
    } catch (e) {
      _mensagem(_erro(e));
    }
  }

  String _erro(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _mensagem(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final lote = _selection.rebanhoSelecionado;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmácia'),
        actions: [
          IconButton(onPressed: _carregando ? null : _carregar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : lote == null
              ? const _SelecioneLote()
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Text('Lote: \${lote.nome}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: _novoProduto, icon: const Icon(Icons.add), label: const Text('Cadastrar produto')),
                      const SizedBox(height: 18),
                      const Text('Estoque da fazenda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_produtos.isEmpty)
                        const Text('Nenhum produto cadastrado.', style: TextStyle(color: Colors.black54))
                      else
                        ..._produtos.map((produto) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
                            title: Text(produto['nome'].toString()),
                            subtitle: Text("\${produto['categoria']} • \${produto['unidade']}"),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("\${produto['estoque']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                TextButton(onPressed: () => _movimentar(produto), child: const Text('Movimentar')),
                              ],
                            ),
                          ),
                        )),
                      const SizedBox(height: 20),
                      const Text('Movimentações deste lote', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_movimentacoes.isEmpty)
                        const Text('Nenhuma movimentação neste lote.', style: TextStyle(color: Colors.black54))
                      else
                        ..._movimentacoes.map((item) {
                          final produto = item['farmacia_produtos'];
                          final nome = produto is Map ? produto['nome'].toString() : 'Produto';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              item['tipo'] == 'entrada' ? Icons.add_circle : Icons.remove_circle,
                              color: item['tipo'] == 'entrada' ? Colors.green : Colors.orange,
                            ),
                            title: Text(nome),
                            subtitle: Text("\${item['tipo']} • \${item['quantidade']}"),
                          );
                        }),
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
      child: Text('Selecione um lote no início para acessar a farmácia.', textAlign: TextAlign.center),
    ),
  );
}

class _ProdutoDialog extends StatefulWidget {
  @override
  State<_ProdutoDialog> createState() => _ProdutoDialogState();
}

class _ProdutoDialogState extends State<_ProdutoDialog> {
  final nome = TextEditingController();
  final unidade = TextEditingController(text: 'unidade');
  final estoque = TextEditingController(text: '0');
  final minimo = TextEditingController(text: '0');
  final principio = TextEditingController();
  String categoria = 'medicamento';

  @override
  void dispose() {
    nome.dispose();
    unidade.dispose();
    estoque.dispose();
    minimo.dispose();
    principio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Novo produto'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          TextField(controller: unidade, decoration: const InputDecoration(labelText: 'Unidade')),
          TextField(controller: principio, decoration: const InputDecoration(labelText: 'Princípio ativo')),
          TextField(controller: estoque, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estoque inicial')),
          TextField(controller: minimo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estoque mínimo')),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () {
          final e = double.tryParse(estoque.text.replaceAll(',', '.')) ?? 0;
          final m = double.tryParse(minimo.text.replaceAll(',', '.')) ?? 0;
          if (nome.text.trim().isEmpty) return;
          Navigator.pop(context, {
            'nome': nome.text,
            'categoria': categoria,
            'unidade': unidade.text,
            'estoque': e,
            'estoqueMinimo': m,
            'principioAtivo': principio.text,
          });
        },
        child: const Text('Salvar'),
      ),
    ],
  );
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
  String? animalId;

  @override
  void dispose() {
    quantidade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.produto['nome'].toString()),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          value: tipo,
          items: const [
            DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
            DropdownMenuItem(value: 'saida', child: Text('Saída')),
          ],
          onChanged: (v) => setState(() => tipo = v!),
          decoration: const InputDecoration(labelText: 'Tipo'),
        ),
        TextField(controller: quantidade, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade')),
        DropdownButtonFormField<String?>(
          value: animalId,
          isExpanded: true,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Lote inteiro')),
            ...widget.animais.map((a) => DropdownMenuItem<String?>(
              value: a['id'].toString(),
              child: Text('Brinco \${a['brinco']}'),
            )),
          ],
          onChanged: (v) => setState(() => animalId = v),
          decoration: const InputDecoration(labelText: 'Animal (opcional)'),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () {
          final q = double.tryParse(quantidade.text.replaceAll(',', '.'));
          if (q == null || q <= 0) return;
          Navigator.pop(context, {'tipo': tipo, 'quantidade': q, 'animalId': animalId});
        },
        child: const Text('Salvar'),
      ),
    ],
  );
}
