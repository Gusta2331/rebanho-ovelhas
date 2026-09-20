import 'package:flutter/material.dart';

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
                        child: Icon(
                          Icons.pets_rounded,
                          color: AppTheme.primaryColor,
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

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<Animal> get _animaisDisponiveis {
    final busca = _buscaController.text.trim().toLowerCase();

    return widget.animais.where((animal) {
      if (animal.sexo != widget.sexoPermitido) {
        return false;
      }

      if (widget.idAnimalAtual != null && animal.id == widget.idAnimalAtual) {
        return false;
      }

      if (busca.isEmpty) {
        return true;
      }

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

  @override
  Widget build(BuildContext context) {
    final animais = _animaisDisponiveis;

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _buscaController,
              onChanged: (_) {
                setState(() {});
              },
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
          Expanded(
            child: animais.isEmpty
                ? _EmptyParentList(tipoAnimal: _tipoAnimal)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: animais.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final animal = animais[index];
                      final selecionado =
                          widget.animalSelecionado?.id == animal.id;

                      return _AnimalParentTile(
                        animal: animal,
                        selecionado: selecionado,
                        onTap: () {
                          Navigator.of(context).pop(animal);
                        },
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
      child: Icon(
        Icons.pets_rounded,
        size: size * 0.48,
        color: AppTheme.primaryColor,
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
            Icon(Icons.pets_outlined, size: 64, color: Colors.grey.shade400),
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
