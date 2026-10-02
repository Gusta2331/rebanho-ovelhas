import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../flock/services/rebanho_selection_service.dart';
import '../models/animal.dart';
import '../services/animal_service.dart';
import '../utils/animal_filters.dart';
import '../utils/animal_list_logic.dart';
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
      cadastro: _cadastroSelecionado,
      denticao: _denticaoSelecionadaFiltro,
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
      final excluidoNoServidor = await AnimalService().excluirAnimal(animal.id, fotoUrl: animal.fotoPath);
      await _carregarAnimais();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              excluidoNoServidor
                  ? 'Animal ${animal.brinco} e seus registros vinculados foram excluídos.'
                  : 'Exclusão do animal ${animal.brinco} salva neste aparelho e será concluída quando a internet voltar.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
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

  FiltroDataNascimento _cadastroSelecionado = FiltroDataNascimento.todas;
  FiltroDenticao _denticaoSelecionadaFiltro = FiltroDenticao.todas;

  bool get _temFiltrosAtivos {
    return _statusSelecionado != StatusAnimal.ativo ||
        _sexoSelecionado != null ||
        _faixaIdadeSelecionada != FaixaIdade.todas ||
        _cadastroSelecionado != FiltroDataNascimento.todas ||
        _denticaoSelecionadaFiltro != FiltroDenticao.todas ||
        _search.trim().isNotEmpty;
  }

  String get _resumoFiltros {
    final partes = <String>[];

    if (_statusSelecionado != StatusAnimal.ativo) {
      partes.add(_statusTexto(_statusSelecionado));
    }

    if (_sexoSelecionado != null) {
      partes.add(_sexoLabel(_sexoSelecionado!));
    }

    if (_faixaIdadeSelecionada != FaixaIdade.todas) {
      partes.add(AnimalFilters.nomeFaixaIdade(_faixaIdadeSelecionada));
    }
    if (_cadastroSelecionado != FiltroDataNascimento.todas) {
      partes.add(_cadastroSelecionado.label);
    }
    if (_denticaoSelecionadaFiltro != FiltroDenticao.todas) {
      partes.add(_denticaoSelecionadaFiltro.label);
    }

    return partes.isEmpty ? 'Ativos' : partes.join(' • ');
  }

  Future<void> _abrirFiltros() async {
    var status = _statusSelecionado;
    var sexo = _sexoSelecionado;
    var idade = _faixaIdadeSelecionada;
    var cadastro = _cadastroSelecionado;
    var denticao = _denticaoSelecionadaFiltro;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            int countStatus(StatusAnimal value) => AnimalListLogic.quantidadePorStatus(
              _animals, value, sexo: sexo, faixaIdade: idade, busca: _search,
              cadastro: cadastro, denticao: denticao,
            );

            int countSex(SexoAnimal? value) => value == null
                ? AnimalListLogic.filtrar(animais: _animals, status: status, sexo: null,
                    faixaIdade: idade, busca: _search, cadastro: cadastro, denticao: denticao).length
                : AnimalListLogic.quantidadePorSexo(_animals, status, value,
                    faixaIdade: idade, busca: _search, cadastro: cadastro, denticao: denticao);

            int countAge(FaixaIdade value) => value == FaixaIdade.todas
                ? AnimalListLogic.filtrar(animais: _animals, status: status, sexo: sexo,
                    faixaIdade: FaixaIdade.todas, busca: _search, cadastro: cadastro, denticao: denticao).length
                : AnimalListLogic.quantidadePorFaixaIdade(_animals, status, value, sexo,
                    busca: _search, cadastro: cadastro, denticao: denticao);

            int countCadastro(FiltroDataNascimento value) => AnimalListLogic.filtrar(
              animais: _animals, status: status, sexo: sexo, faixaIdade: idade,
              busca: _search, cadastro: value, denticao: denticao).length;

            int countDenticao(FiltroDenticao value) => AnimalListLogic.filtrar(
              animais: _animals, status: status, sexo: sexo, faixaIdade: idade,
              busca: _search, cadastro: cadastro, denticao: value).length;

            Widget chip(String label, int count, bool selected, VoidCallback onTap) {
              return FilterChip(
                label: Text('$label $count'),
                selected: selected,
                onSelected: (_) => onTap(),
                showCheckmark: true,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              );
            }

            Widget section(String title, List<Widget> chips) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 5, runSpacing: 3, children: chips),
                  ],
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor)),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                status = StatusAnimal.ativo;
                                sexo = null;
                                idade = FaixaIdade.todas;
                                cadastro = FiltroDataNascimento.todas;
                                denticao = FiltroDenticao.todas;
                              });
                            },
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      section('Status', StatusAnimal.values.map((value) => chip(
                        _statusTexto(value), countStatus(value), status == value,
                        () => setSheetState(() => status = value),
                      )).toList()),
                      section('Sexo', [
                        chip('Todos', countSex(null), sexo == null, () => setSheetState(() => sexo = null)),
                        chip('♀ Fêmeas', countSex(SexoAnimal.femea), sexo == SexoAnimal.femea, () => setSheetState(() => sexo = SexoAnimal.femea)),
                        chip('♂ Machos', countSex(SexoAnimal.macho), sexo == SexoAnimal.macho, () => setSheetState(() => sexo = SexoAnimal.macho)),
                      ]),
                      section('Idade', FaixaIdade.values.map((value) => chip(
                        AnimalFilters.nomeFaixaIdade(value), countAge(value), idade == value,
                        () => setSheetState(() => idade = value),
                      )).toList()),
                      section('Data de nascimento', FiltroDataNascimento.values.map((value) => chip(
                        value.label, countCadastro(value), cadastro == value,
                        () => setSheetState(() => cadastro = value),
                      )).toList()),
                      section('Dentição', FiltroDenticao.values.map((value) => chip(
                        value.label, countDenticao(value), denticao == value,
                        () => setSheetState(() => denticao = value),
                      )).toList()),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _statusSelecionado = status;
                              _sexoSelecionado = sexo;
                              _faixaIdadeSelecionada = idade;
                              _cadastroSelecionado = cadastro;
                              _denticaoSelecionadaFiltro = denticao;
                            });
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Aplicar filtros'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
                      AppAssetIcon(assetPath: 'assets/images/icon_animais.png', size: 42),
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
                          const AppAssetIcon(
                            assetPath: 'assets/images/icon_animais.png',
                            size: 34,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: _abrirFiltros,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE0E5DC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_list_rounded, size: 19, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            const Text('Filtros', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textColor)),
                            if (_temFiltrosAtivos) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${[
                                    _statusSelecionado != StatusAnimal.ativo,
                                    _sexoSelecionado != null,
                                    _faixaIdadeSelecionada != FaixaIdade.todas,
                                    _cadastroSelecionado != FiltroDataNascimento.todas,
                                    _denticaoSelecionadaFiltro != FiltroDenticao.todas,
                                  ].where((ativo) => ativo).length}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Flexible(
                              child: Text(
                                _temFiltrosAtivos ? _resumoFiltros : 'Ativos • ${animals.length}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.tune_rounded, size: 17, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          '${animals.length} '
                          '${animals.length == 1 ? 'animal' : 'animais'} encontrados',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const Spacer(),
                        if (_temFiltrosAtivos)
                          const Icon(
                            Icons.tune_rounded,
                            size: 17,
                            color: AppTheme.primaryColor,
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
              child: const AppAssetIcon(assetPath: 'assets/images/icon_animais.png', size: 38),
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
