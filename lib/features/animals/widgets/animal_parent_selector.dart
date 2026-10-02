import 'package:flutter/material.dart';

import '../../../core/widgets/app_asset_icon.dart';

import '../../../core/theme/app_theme.dart';
import '../models/animal.dart';

class AnimalParentSelector extends StatelessWidget {
  final String titulo;
  final String textoVazio;
  final Animal? animalSelecionado;
  final SexoAnimal sexoPermitido;
  final List<Animal> animais;
  final String? idAnimalAtual;
  final ValueChanged<Animal?> onChanged;

  const AnimalParentSelector({
    super.key,
    required this.titulo,
    required this.textoVazio,
    required this.animalSelecionado,
    required this.sexoPermitido,
    required this.animais,
    required this.idAnimalAtual,
    required this.onChanged,
  });

  Future<void> _selecionarAnimal(BuildContext context) async {
    final resultado = await Navigator.of(context).push<Animal>(
      MaterialPageRoute(
        builder: (context) => _AnimalParentSelectionPage(
          titulo: titulo,
          animais: animais,
          sexoPermitido: sexoPermitido,
          idAnimalAtual: idAnimalAtual,
          animalSelecionado: animalSelecionado,
        ),
      ),
    );

    if (resultado != null) {
      onChanged(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animal = animalSelecionado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selecionarAnimal(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E5DC)),
            ),
            child: animal == null
                ? Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const AppAssetIcon(
                          assetPath: 'assets/images/icon_animais.png',
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          textoVazio,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _AnimalParentAvatar(animal: animal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              animal.nome?.isNotEmpty == true
                                  ? animal.nome!
                                  : 'Animal ${animal.brinco}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Brinco ${animal.brinco} • ${animal.raca}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover',
                        onPressed: () {
                          onChanged(null);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _AnimalParentSelectionPage extends StatefulWidget {
  final String titulo;
  final List<Animal> animais;
  final SexoAnimal sexoPermitido;
  final String? idAnimalAtual;
  final Animal? animalSelecionado;

  const _AnimalParentSelectionPage({
    required this.titulo,
    required this.animais,
    required this.sexoPermitido,
    required this.idAnimalAtual,
    required this.animalSelecionado,
  });

  @override
  State<_AnimalParentSelectionPage> createState() =>
      _AnimalParentSelectionPageState();
}

class _AnimalParentSelectionPageState
    extends State<_AnimalParentSelectionPage> {
  final TextEditingController _buscaController = TextEditingController();

  StatusAnimal _statusSelecionado = StatusAnimal.ativo;
  bool _somenteAptosParaReproducao = true;

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  bool _idadeApta(Animal animal) {
    final nascimento = animal.dataNascimento;
    if (nascimento == null) return false;

    final hoje = DateTime.now();
    var meses =
        (hoje.year - nascimento.year) * 12 + hoje.month - nascimento.month;
    if (hoje.day < nascimento.day) meses--;

    // A idade reprodutiva varia com raça, nutrição e desenvolvimento.
    // Para o filtro do app usamos referências práticas para ovinos:
    // fêmeas: a partir de 10 meses;
    // machos: a partir de 12 meses.
    final idadeMinima = animal.sexo == SexoAnimal.femea ? 10 : 12;

    return meses >= idadeMinima;
  }

  int _idadeMinimaReproducao() {
    return widget.sexoPermitido == SexoAnimal.femea ? 10 : 12;
  }

  List<Animal> _animaisPorStatus(
    StatusAnimal status, {
    required bool somenteAptos,
  }) {
    return widget.animais.where((animal) {
      if (animal.sexo != widget.sexoPermitido) return false;
      if (widget.idAnimalAtual != null && animal.id == widget.idAnimalAtual) {
        return false;
      }
      if (animal.status != status) return false;
      if (somenteAptos && !_idadeApta(animal)) return false;
      return true;
    }).toList();
  }

  List<Animal> get _animaisDisponiveis {
    final busca = _buscaController.text.trim().toLowerCase();

    return _animaisPorStatus(
      _statusSelecionado,
      somenteAptos: _somenteAptosParaReproducao,
    ).where((animal) {
      if (busca.isEmpty) return true;

      final brinco = animal.brinco.toLowerCase();
      final nome = animal.nome?.toLowerCase() ?? '';
      final raca = animal.raca.toLowerCase();

      return brinco.contains(busca) ||
          nome.contains(busca) ||
          raca.contains(busca);
    }).toList();
  }

  String get _tipoAnimal {
    return widget.sexoPermitido == SexoAnimal.femea ? 'fêmeas' : 'machos';
  }

  String get _textoFiltroIdade {
    return _somenteAptosParaReproducao
        ? 'Aptos para reprodução'
        : 'Todas as idades';
  }

  String _statusLabel(StatusAnimal status) {
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

  Future<void> _abrirFiltros() async {
    var status = _statusSelecionado;
    var somenteAptos = _somenteAptosParaReproducao;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget chip(
              String label,
              int count,
              bool selected,
              VoidCallback onTap,
            ) {
              return FilterChip(
                label: Text('$label $count'),
                selected: selected,
                onSelected: (_) => onTap(),
                showCheckmark: true,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
              );
            }

            final statusChips = StatusAnimal.values.map((value) {
              return chip(
                _statusLabel(value),
                _animaisPorStatus(
                  value,
                  somenteAptos: somenteAptos,
                ).length,
                status == value,
                () => setSheetState(() => status = value),
              );
            }).toList();

            final aptosCount =
                _animaisPorStatus(status, somenteAptos: true).length;
            final todasIdadesCount =
                _animaisPorStatus(status, somenteAptos: false).length;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filtros de seleção',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              status = StatusAnimal.ativo;
                              somenteAptos = true;
                            });
                          },
                          child: const Text('Limpar'),
                        ),
                      ],
                    ),
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: statusChips,
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'Idade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        chip(
                          'Aptos para reprodução',
                          aptosCount,
                          somenteAptos,
                          () => setSheetState(() => somenteAptos = true),
                        ),
                        chip(
                          'Todas as idades',
                          todasIdadesCount,
                          !somenteAptos,
                          () => setSheetState(() => somenteAptos = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _statusSelecionado = status;
                            _somenteAptosParaReproducao = somenteAptos;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ],
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
    final animais = _animaisDisponiveis;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          IconButton(
            onPressed: _abrirFiltros,
            tooltip: 'Filtros',
            icon: const Icon(Icons.filter_list_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
            child: TextField(
              controller: _buscaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por brinco, nome ou raça',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _buscaController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        onPressed: () {
                          _buscaController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$_textoFiltroIdade • ${_statusLabel(_statusSelecionado)} • '
                '${animais.length} ${animais.length == 1 ? 'animal' : 'animais'}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
          Expanded(
            child: animais.isEmpty
                ? _EmptyParentList(tipoAnimal: _tipoAnimal)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: animais.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final animal = animais[index];
                      final selecionado =
                          widget.animalSelecionado?.id == animal.id;

                      return _AnimalParentTile(
                        animal: animal,
                        selecionado: selecionado,
                        onTap: () => Navigator.of(context).pop(animal),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
class _AnimalParentTile extends StatelessWidget {
  final Animal animal;
  final bool selecionado;
  final VoidCallback onTap;

  const _AnimalParentTile({
    required this.animal,
    required this.selecionado,
    required this.onTap,
  });

  String _statusLabel() {
    switch (animal.status) {
      case StatusAnimal.ativo:
        return 'Ativo';

      case StatusAnimal.vendido:
        return 'Vendido';

      case StatusAnimal.morto:
        return 'Morto';

      case StatusAnimal.descartado:
        return 'Descartado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _AnimalParentAvatar(animal: animal, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.nome?.isNotEmpty == true
                          ? animal.nome!
                          : 'Animal ${animal.brinco}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Brinco ${animal.brinco}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${animal.raca} • ${_statusLabel()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selecionado)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primaryColor,
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimalParentAvatar extends StatelessWidget {
  final Animal animal;
  final double size;

  const _AnimalParentAvatar({required this.animal, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final fotoPath = animal.fotoPath;

    if (fotoPath != null && fotoPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          fotoPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _fallback();
          },
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppAssetIcon(
        assetPath: 'assets/images/icon_animais.png',
        size: size * 0.48,
      ),
    );
  }
}

class _EmptyParentList extends StatelessWidget {
  final String tipoAnimal;

  const _EmptyParentList({required this.tipoAnimal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAssetIcon(assetPath: 'assets/images/icon_animais.png', size: 64),
            const SizedBox(height: 16),
            Text(
              'Nenhum animal encontrado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cadastre pelo menos uma das $tipoAnimal '
              'para poder selecionar como progenitor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
