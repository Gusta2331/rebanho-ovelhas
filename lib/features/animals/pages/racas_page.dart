import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/racas.dart';
import '../models/animal.dart';

class RacasPage extends StatefulWidget {
  final bool modoSelecao;
  final List<Animal> animais;

  const RacasPage({
    super.key,
    this.modoSelecao = false,
    this.animais = const [],
  });

  @override
  State<RacasPage> createState() => _RacasPageState();
}

class _RacasPageState extends State<RacasPage> {
  String _busca = '';

  List<Raca> get _racasFiltradas {
    if (_busca.trim().isEmpty) {
      return RacasData.racas;
    }

    final busca = _busca.trim().toLowerCase();

    return RacasData.racas.where((raca) {
      return raca.nome.toLowerCase().contains(busca);
    }).toList();
  }

  int _quantidadeAnimaisUsandoRaca(Raca raca) {
    return widget.animais.where((animal) {
      return animal.raca.trim().toLowerCase() == raca.nome.trim().toLowerCase();
    }).length;
  }

  bool _racaEstaEmUso(Raca raca) {
    return _quantidadeAnimaisUsandoRaca(raca) > 0;
  }

  Future<void> _adicionarRaca() async {
    final nome = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return const _NovaRacaDialog();
      },
    );

    if (nome == null || nome.trim().isEmpty || !mounted) {
      return;
    }

    final nomeNormalizado = nome.trim().toLowerCase();

    final jaExiste = RacasData.racas.any(
      (raca) => raca.nome.trim().toLowerCase() == nomeNormalizado,
    );

    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Essa raça já está cadastrada.')),
      );

      return;
    }

    setState(() {
      RacasData.racas.add(
        Raca(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          nome: nome.trim(),
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Raça "$nome" adicionada com sucesso.')),
    );
  }

  Future<void> _editarRaca(Raca raca) async {
    if (_racaEstaEmUso(raca)) {
      final quantidade = _quantidadeAnimaisUsandoRaca(raca);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não é possível editar "${raca.nome}". '
            '$quantidade ${quantidade == 1 ? 'animal utiliza' : 'animais utilizam'} esta raça.',
          ),
        ),
      );

      return;
    }

    final novoNome = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _EditarRacaDialog(nomeAtual: raca.nome);
      },
    );

    if (novoNome == null || novoNome.trim().isEmpty || !mounted) {
      return;
    }

    final nomeNormalizado = novoNome.trim().toLowerCase();

    final jaExiste = RacasData.racas.any(
      (outraRaca) =>
          outraRaca.id != raca.id &&
          outraRaca.nome.trim().toLowerCase() == nomeNormalizado,
    );

    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Essa raça já está cadastrada.')),
      );

      return;
    }

    final indice = RacasData.racas.indexWhere(
      (outraRaca) => outraRaca.id == raca.id,
    );

    if (indice == -1) {
      return;
    }

    setState(() {
      RacasData.racas[indice] = Raca(id: raca.id, nome: novoNome.trim());
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Raça "$novoNome" atualizada com sucesso.')),
    );
  }

  Future<void> _excluirRaca(Raca raca) async {
    if (_racaEstaEmUso(raca)) {
      final quantidade = _quantidadeAnimaisUsandoRaca(raca);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não é possível excluir "${raca.nome}". '
            '$quantidade ${quantidade == 1 ? 'animal utiliza' : 'animais utilizam'} esta raça.',
          ),
        ),
      );

      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir raça?'),
          content: Text(
            'Tem certeza que deseja excluir a raça "${raca.nome}"?\n\n'
            'Essa ação não poderá ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    if (_racaEstaEmUso(raca)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Essa raça passou a ser utilizada e não pode ser excluída.',
          ),
        ),
      );

      return;
    }

    setState(() {
      RacasData.racas.removeWhere((outraRaca) => outraRaca.id == raca.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Raça "${raca.nome}" excluída com sucesso.')),
    );
  }

  void _selecionarRaca(Raca raca) {
    if (!widget.modoSelecao) {
      return;
    }

    Navigator.of(context).pop(raca.nome);
  }

  void _mostrarOpcoesRaca(Raca raca) {
    if (widget.modoSelecao) {
      return;
    }

    final emUso = _racaEstaEmUso(raca);
    final quantidade = _quantidadeAnimaisUsandoRaca(raca);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.pets_rounded,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        raca.nome,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (emUso)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$quantidade ${quantidade == 1 ? 'animal utiliza' : 'animais utilizam'} esta raça. '
                            'Para preservar o histórico, ela não pode ser editada ou excluída.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (emUso) const SizedBox(height: 12),
                ListTile(
                  enabled: !emUso,
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar raça'),
                  subtitle: emUso
                      ? const Text('Raça em uso por animais')
                      : null,
                  onTap: emUso
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          _editarRaca(raca);
                        },
                ),
                ListTile(
                  enabled: !emUso,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: emUso ? Colors.black26 : Colors.red,
                  ),
                  title: Text(
                    'Excluir raça',
                    style: TextStyle(
                      color: emUso ? Colors.black38 : Colors.red,
                    ),
                  ),
                  subtitle: emUso
                      ? const Text('Raça em uso por animais')
                      : null,
                  onTap: emUso
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          _excluirRaca(raca);
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final racas = _racasFiltradas;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.modoSelecao ? 'Selecionar raça' : 'Biblioteca de raças',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _busca = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Buscar raça',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${racas.length} ${racas.length == 1 ? 'raça' : 'raças'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: racas.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma raça encontrada.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: racas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final raca = racas[index];
                        final emUso = _racaEstaEmUso(raca);
                        final quantidade = _quantidadeAnimaisUsandoRaca(raca);

                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: widget.modoSelecao
                                ? () => _selecionarRaca(raca)
                                : () => _mostrarOpcoesRaca(raca),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E9E1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.pets_rounded,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          raca.nome,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textColor,
                                          ),
                                        ),
                                        if (!widget.modoSelecao && emUso) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '$quantidade ${quantidade == 1 ? 'animal cadastrado' : 'animais cadastrados'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (widget.modoSelecao)
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.black38,
                                    )
                                  else
                                    const Icon(
                                      Icons.more_vert_rounded,
                                      color: Colors.black38,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.modoSelecao
          ? null
          : FloatingActionButton.extended(
              onPressed: _adicionarRaca,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova raça'),
            ),
    );
  }
}

class _NovaRacaDialog extends StatefulWidget {
  const _NovaRacaDialog();

  @override
  State<_NovaRacaDialog> createState() => _NovaRacaDialogState();
}

class _NovaRacaDialogState extends State<_NovaRacaDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _adicionar() {
    final nome = _controller.text.trim();

    if (nome.isEmpty) {
      return;
    }

    Navigator.of(context).pop(nome);
  }

  void _cancelar() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova raça'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _adicionar(),
        decoration: const InputDecoration(
          labelText: 'Nome da raça',
          hintText: 'Ex.: Bergamácia',
        ),
      ),
      actions: [
        TextButton(onPressed: _cancelar, child: const Text('Cancelar')),
        FilledButton(
          onPressed: _adicionar,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _EditarRacaDialog extends StatefulWidget {
  final String nomeAtual;

  const _EditarRacaDialog({required this.nomeAtual});

  @override
  State<_EditarRacaDialog> createState() => _EditarRacaDialogState();
}

class _EditarRacaDialogState extends State<_EditarRacaDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.nomeAtual);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _salvar() {
    final nome = _controller.text.trim();

    if (nome.isEmpty) {
      return;
    }

    Navigator.of(context).pop(nome);
  }

  void _cancelar() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar raça'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _salvar(),
        decoration: const InputDecoration(
          labelText: 'Nome da raça',
          hintText: 'Ex.: Bergamácia',
        ),
      ),
      actions: [
        TextButton(onPressed: _cancelar, child: const Text('Cancelar')),
        FilledButton(
          onPressed: _salvar,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
