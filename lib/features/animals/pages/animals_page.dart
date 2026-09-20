import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/animal.dart';
import '../utils/animal_filters.dart';
import '../utils/animal_list_logic.dart';
import '../widgets/animal_filters.dart';
import '../widgets/animal_photo.dart';
import '../widgets/animal_list_item.dart';
import 'animal_details_page.dart';
import 'animal_form_page.dart';
import 'racas_page.dart';

class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  final List<Animal> _animals = [
    Animal(
      brinco: '001',
      nome: 'Branquinha',
      sexo: SexoAnimal.femea,
      raca: 'Santa Inês',
      status: StatusAnimal.ativo,
    ),
    Animal(
      brinco: '002',
      nome: 'Morena',
      sexo: SexoAnimal.femea,
      raca: 'Dorper',
      status: StatusAnimal.ativo,
    ),
    Animal(
      brinco: '003',
      nome: 'Trovão',
      sexo: SexoAnimal.macho,
      raca: 'Santa Inês',
      status: StatusAnimal.ativo,
    ),
  ];

  String _search = '';

  StatusAnimal _statusSelecionado = StatusAnimal.ativo;

  SexoAnimal? _sexoSelecionado;

  FaixaIdade _faixaIdadeSelecionada = FaixaIdade.todas;

  List<Animal> get _filteredAnimals {
    return AnimalListLogic.filtrar(
      animais: _animals,
      status: _statusSelecionado,
      sexo: _sexoSelecionado,
      faixaIdade: _faixaIdadeSelecionada,
      busca: _search,
    );
  }

  String _statusTexto(StatusAnimal status) {
    switch (status) {
      case StatusAnimal.ativo:
        return 'Ativos';

      case StatusAnimal.vendido:
        return 'Vendidos';

      case StatusAnimal.morto:
        return 'Mortos';

      case StatusAnimal.descartado:
        return 'Descartados';
    }
  }

  Color _statusCor(StatusAnimal status) {
    switch (status) {
      case StatusAnimal.ativo:
        return AppTheme.primaryColor;

      case StatusAnimal.vendido:
        return Colors.blue;

      case StatusAnimal.morto:
        return Colors.red;

      case StatusAnimal.descartado:
        return Colors.orange;
    }
  }

  IconData _statusIcon(StatusAnimal status) {
    switch (status) {
      case StatusAnimal.ativo:
        return Icons.check_circle_outline_rounded;

      case StatusAnimal.vendido:
        return Icons.sell_outlined;

      case StatusAnimal.morto:
        return Icons.remove_circle_outline_rounded;

      case StatusAnimal.descartado:
        return Icons.block_outlined;
    }
  }

  String _sexoLabel(SexoAnimal sexo) {
    switch (sexo) {
      case SexoAnimal.femea:
        return 'Fêmea';

      case SexoAnimal.macho:
        return 'Macho';
    }
  }

  IconData _sexoIcon(SexoAnimal sexo) {
    switch (sexo) {
      case SexoAnimal.femea:
        return Icons.female_rounded;

      case SexoAnimal.macho:
        return Icons.male_rounded;
    }
  }

  Future<void> _adicionarAnimal() async {
    final brincosExistentes = _animals
        .where((animal) => animal.status == StatusAnimal.ativo)
        .map((animal) => animal.brinco)
        .toSet();

    final animal = await Navigator.of(context).push<Animal>(
      MaterialPageRoute(
        builder: (context) => AnimalFormPage(
          brincosExistentes: brincosExistentes,
          animais: _animals,
        ),
      ),
    );

    if (animal == null || !mounted) {
      return;
    }

    final novoBrinco = AnimalListLogic.normalizarBrinco(animal.brinco);

    final jaExiste = _animals.any(
      (animalExistente) =>
          animalExistente.status == StatusAnimal.ativo &&
          AnimalListLogic.normalizarBrinco(animalExistente.brinco) ==
              novoBrinco,
    );

    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O brinco ${animal.brinco} já está sendo usado '
            'por um animal ativo.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _animals.add(animal);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Animal ${animal.brinco} cadastrado com sucesso.'),
      ),
    );
  }

  Future<void> _editarAnimal(Animal animal) async {
    final brincosExistentes = _animals
        .where(
          (outroAnimal) =>
              outroAnimal.status == StatusAnimal.ativo &&
              outroAnimal.id != animal.id,
        )
        .map((animal) => animal.brinco)
        .toSet();

    final animalEditado = await Navigator.of(context).push<Animal>(
      MaterialPageRoute(
        builder: (context) => AnimalFormPage(
          brincosExistentes: brincosExistentes,
          animais: _animals,
          animalParaEditar: animal,
        ),
      ),
    );

    if (animalEditado == null || !mounted) {
      return;
    }

    final indice = _animals.indexWhere(
      (animalAtual) => animalAtual.id == animal.id,
    );

    if (indice == -1) {
      return;
    }

    setState(() {
      _animals[indice] = animalEditado;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Animal ${animalEditado.brinco} atualizado com sucesso.'),
      ),
    );
  }

  Future<void> _excluirAnimal(Animal animal) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir animal?'),
          content: Text(
            'Tem certeza que deseja excluir o animal '
            '"${animal.nome ?? 'Sem nome'}" '
            'com brinco ${animal.brinco}?\n\n'
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

    setState(() {
      _animals.removeWhere((animalAtual) => animalAtual.id == animal.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Animal ${animal.brinco} excluído.')),
    );
  }

  void _mostrarOpcoesAnimal(Animal animal) {
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
                    AnimalPhoto(
                      fotoPath: animal.fotoPath,
                      size: 50,
                      borderRadius: 15,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            animal.nome ?? 'Sem nome',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Brinco ${animal.brinco} • ${animal.raca}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar animal'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    _editarAnimal(animal);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Excluir animal',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    _excluirAnimal(animal);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirFichaAnimal(Animal animal) async {
    final animalAtualizado = await Navigator.of(context).push<Animal>(
      MaterialPageRoute(
        builder: (context) =>
            AnimalDetailsPage(animal: animal, animais: _animals),
      ),
    );

    if (animalAtualizado == null || !mounted) {
      return;
    }

    final indice = _animals.indexWhere(
      (animalAtual) => animalAtual.id == animal.id,
    );

    if (indice == -1) {
      return;
    }

    setState(() {
      _animals[indice] = animalAtualizado;
    });
  }

  void _abrirBibliotecaRacas() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => RacasPage(animais: _animals)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animals = _filteredAnimals;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Animais',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (value) {
              if (value == 'racas') {
                _abrirBibliotecaRacas();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'racas',
                  child: Row(
                    children: [
                      Icon(Icons.pets_rounded),
                      SizedBox(width: 12),
                      Text('Biblioteca de raças'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Buscar por brinco, nome ou raça',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: StatusAnimal.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final status = StatusAnimal.values[index];

                  return AnimalStatusFilter(
                    label: _statusTexto(status),
                    quantidade: AnimalListLogic.quantidadePorStatus(
                      _animals,
                      status,
                    ),
                    icon: _statusIcon(status),
                    color: _statusCor(status),
                    selected: _statusSelecionado == status,
                    onTap: () {
                      setState(() {
                        _statusSelecionado = status;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  AnimalSexFilter(
                    label: 'Todos',
                    icon: Icons.pets_rounded,
                    quantidade: AnimalListLogic.porStatus(
                      _animals,
                      _statusSelecionado,
                    ).length,
                    selected: _sexoSelecionado == null,
                    onTap: () {
                      setState(() {
                        _sexoSelecionado = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  AnimalSexFilter(
                    label: 'Fêmeas',
                    icon: Icons.female_rounded,
                    quantidade: AnimalListLogic.quantidadePorSexo(
                      _animals,
                      _statusSelecionado,
                      SexoAnimal.femea,
                    ),
                    selected: _sexoSelecionado == SexoAnimal.femea,
                    onTap: () {
                      setState(() {
                        _sexoSelecionado = SexoAnimal.femea;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  AnimalSexFilter(
                    label: 'Machos',
                    icon: Icons.male_rounded,
                    quantidade: AnimalListLogic.quantidadePorSexo(
                      _animals,
                      _statusSelecionado,
                      SexoAnimal.macho,
                    ),
                    selected: _sexoSelecionado == SexoAnimal.macho,
                    onTap: () {
                      setState(() {
                        _sexoSelecionado = SexoAnimal.macho;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: FaixaIdade.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final faixa = FaixaIdade.values[index];

                  return AnimalAgeFilter(
                    label: AnimalFilters.nomeFaixaIdade(faixa),
                    quantidade: AnimalListLogic.quantidadePorFaixaIdade(
                      _animals,
                      _statusSelecionado,
                      faixa,
                    ),
                    selected: _faixaIdadeSelecionada == faixa,
                    onTap: () {
                      setState(() {
                        _faixaIdadeSelecionada = faixa;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${animals.length} '
                    '${animals.length == 1 ? 'animal' : 'animais'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _statusTexto(_statusSelecionado),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _statusCor(_statusSelecionado),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: animals.isEmpty
                  ? EmptyAnimalsState(
                      status: _statusSelecionado,
                      search: _search,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: animals.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final animal = animals[index];

                        return AnimalListItem(
                          animal: animal,
                          sexoLabel: _sexoLabel(animal.sexo),
                          sexoIcon: _sexoIcon(animal.sexo),
                          statusColor: _statusCor(animal.status),
                          onTap: () {
                            _abrirFichaAnimal(animal);
                          },
                          onLongPress: () {
                            _mostrarOpcoesAnimal(animal);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _statusSelecionado == StatusAnimal.ativo
          ? FloatingActionButton.extended(
              onPressed: _adicionarAnimal,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar'),
            )
          : null,
    );
  }
}
