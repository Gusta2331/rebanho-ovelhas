import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../models/animal.dart';
import '../services/animal_service.dart';
import '../utils/animal_filters.dart';
import '../utils/animal_list_logic.dart';
import '../widgets/animal_filters.dart';
import '../widgets/animal_list_item.dart';
import '../widgets/animal_photo.dart';
import 'animal_details_page.dart';
import 'animal_form_page.dart';
import 'animal_help_page.dart';
import 'racas_page.dart';

class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  final AnimalService _animalService = AnimalService();

  final RebanhoSelectionService _rebanhoSelectionService =
      RebanhoSelectionService.instance;

  final List<Animal> _animals = [];

  String _search = '';

  StatusAnimal _statusSelecionado = StatusAnimal.ativo;

  SexoAnimal? _sexoSelecionado;

  FaixaIdade _faixaIdadeSelecionada = FaixaIdade.todas;

  bool _carregando = true;

  String? _erro;

  String? _ultimoRebanhoIdCarregado;

  List<Animal> get _filteredAnimals {
    return AnimalListLogic.filtrar(
      animais: _animals,
      status: _statusSelecionado,
      sexo: _sexoSelecionado,
      faixaIdade: _faixaIdadeSelecionada,
      busca: _search,
    );
  }

  @override
  void initState() {
    super.initState();
    _carregarAnimais();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final rebanhoId = _rebanhoSelectionService.rebanhoSelecionadoId;

    if (rebanhoId != null && rebanhoId != _ultimoRebanhoIdCarregado) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _carregarAnimais();
      });
    }
  }

  Future<void> _carregarAnimais() async {
    final rebanhoSelecionado = _rebanhoSelectionService.rebanhoSelecionado;

    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      if (rebanhoSelecionado == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _animals.clear();
          _ultimoRebanhoIdCarregado = null;
          _carregando = false;
        });

        return;
      }

      final registros = await _animalService.getTodosAnimais(
        rebanhoId: rebanhoSelecionado.id,
      );

      final animais = registros.map(Animal.fromMap).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _animals
          ..clear()
          ..addAll(animais);

        _ultimoRebanhoIdCarregado = rebanhoSelecionado.id;

        _carregando = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
        _erro = _mensagemErro(error);
      });
    }
  }

  String _mensagemErro(Object error) {
    final texto = error.toString();

    if (texto.startsWith('Exception: ')) {
      return texto.substring(11);
    }

    return 'Não foi possível carregar os animais.';
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
    final rebanhoSelecionado = _rebanhoSelectionService.rebanhoSelecionado;

    if (rebanhoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um rebanho antes de adicionar um animal.'),
        ),
      );

      return;
    }

    try {
      final brincosExistentes = _animals.map((animal) => animal.brinco).toSet();

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

      await _carregarAnimais();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Animal ${animal.brinco} cadastrado com sucesso.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mensagemErro(error))));
    }
  }

  Future<void> _editarAnimal(Animal animal) async {
    final brincosExistentes = _animals
        .where((outroAnimal) => outroAnimal.id != animal.id)
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

    await _carregarAnimais();

    if (!mounted) {
      return;
    }

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
            'Excluir ${animal.nome ?? 'o animal'} (brinco ${animal.brinco}) apagará permanentemente '
            'a ficha e os registros ligados somente a ele: saúde, pesagens, venda, despesas/receitas '
            'vinculadas e registros de reprodução. Cordeiros existentes permanecem, mas perdem esta filiação.\n\n'
            'Esta ação exige internet e não pode ser desfeita. Deseja continuar?',
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
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Excluir permanentemente'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    try {
      await AnimalService().excluirAnimal(animal.id);
      await _carregarAnimais();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Animal ${animal.brinco} e seus registros vinculados foram excluídos.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
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

    await _carregarAnimais();
  }

  void _abrirBibliotecaRacas() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => RacasPage(animais: _animals)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animals = _filteredAnimals;

    final rebanhoSelecionado = _rebanhoSelectionService.rebanhoSelecionado;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Animais',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AnimalHelpPage()));
            },
            tooltip: 'Ajuda',
            icon: const Icon(Icons.help_outline),
          ),
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
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
            ? _buildErro()
            : rebanhoSelecionado == null
            ? _buildSemRebanho()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rebanho selecionado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  rebanhoSelecionado.nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
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
              onPressed: _carregando ? null : _adicionarAnimal,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar'),
            )
          : null,
    );
  }

  Widget _buildSemRebanho() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 38,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nenhum rebanho selecionado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Volte para o início e selecione um rebanho '
              'para visualizar os animais.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: Colors.black38,
            ),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar os animais.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _erro ?? 'Tente novamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _carregarAnimais,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
