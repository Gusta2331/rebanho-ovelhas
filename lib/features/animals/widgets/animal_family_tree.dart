import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/animal.dart';
import '../pages/animal_details_page.dart';
import 'animal_photo.dart';

class AnimalFamilyTree extends StatelessWidget {
  final Animal animal;
  final List<Animal> animais;

  const AnimalFamilyTree({
    super.key,
    required this.animal,
    required this.animais,
  });

  Animal? _buscarPorId(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }

    for (final outroAnimal in animais) {
      if (outroAnimal.id == id) {
        return outroAnimal;
      }
    }

    return null;
  }

  List<Animal> _obterFilhos(Animal animal) {
    return animais.where((outroAnimal) {
      if (outroAnimal.id == animal.id) {
        return false;
      }

      return outroAnimal.idMae == animal.id || outroAnimal.idPai == animal.id;
    }).toList();
  }

  List<Animal> _obterPais(List<Animal> geracao) {
    final pais = <Animal>[];
    final idsAdicionados = <String>{};

    for (final animal in geracao) {
      final mae = _buscarPorId(animal.idMae);
      final pai = _buscarPorId(animal.idPai);

      if (mae != null && idsAdicionados.add(mae.id)) {
        pais.add(mae);
      }

      if (pai != null && idsAdicionados.add(pai.id)) {
        pais.add(pai);
      }
    }

    return pais;
  }

  List<Animal> _obterFilhosDaGeracao(List<Animal> geracao) {
    final filhos = <Animal>[];
    final idsAdicionados = <String>{};

    for (final animal in geracao) {
      for (final filho in _obterFilhos(animal)) {
        if (idsAdicionados.add(filho.id)) {
          filhos.add(filho);
        }
      }
    }

    return filhos;
  }

  List<List<Animal>> _obterGeracoesAnteriores() {
    final geracoes = <List<Animal>>[];
    var geracaoAtual = <Animal>[animal];

    final idsVisitados = <String>{animal.id};

    while (true) {
      final pais = _obterPais(geracaoAtual);

      final paisNovos = pais.where((pai) {
        return !idsVisitados.contains(pai.id);
      }).toList();

      if (paisNovos.isEmpty) {
        break;
      }

      for (final pai in paisNovos) {
        idsVisitados.add(pai.id);
      }

      geracoes.add(paisNovos);
      geracaoAtual = paisNovos;
    }

    return geracoes;
  }

  List<List<Animal>> _obterProximasGeracoes() {
    final geracoes = <List<Animal>>[];
    var geracaoAtual = <Animal>[animal];

    final idsVisitados = <String>{animal.id};

    while (true) {
      final filhos = _obterFilhosDaGeracao(geracaoAtual);

      final filhosNovos = filhos.where((filho) {
        return !idsVisitados.contains(filho.id);
      }).toList();

      if (filhosNovos.isEmpty) {
        break;
      }

      for (final filho in filhosNovos) {
        idsVisitados.add(filho.id);
      }

      geracoes.add(filhosNovos);
      geracaoAtual = filhosNovos;
    }

    return geracoes;
  }

  String _nomeAnimal(Animal animal) {
    final nome = animal.nome?.trim();

    if (nome != null && nome.isNotEmpty) {
      return nome;
    }

    return 'Animal ${animal.brinco}';
  }

  String _sexoTexto(Animal animal) {
    switch (animal.sexo) {
      case SexoAnimal.femea:
        return 'Fêmea';

      case SexoAnimal.macho:
        return 'Macho';
    }
  }

  Color _sexoCor(Animal animal) {
    switch (animal.sexo) {
      case SexoAnimal.femea:
        return Colors.pink;

      case SexoAnimal.macho:
        return Colors.blue;
    }
  }

  String _tituloGeracaoAnterior(int indice) {
    if (indice == 0) {
      return 'Pais';
    }

    if (indice == 1) {
      return 'Avós';
    }

    if (indice == 2) {
      return 'Bisavós';
    }

    return '${indice + 1}ª geração anterior';
  }

  String _tituloProximaGeracao(int indice) {
    if (indice == 0) {
      return 'Filhos';
    }

    if (indice == 1) {
      return 'Netos';
    }

    if (indice == 2) {
      return 'Bisnetos';
    }

    return '${indice + 1}ª geração seguinte';
  }

  @override
  Widget build(BuildContext context) {
    final geracoesAnteriores = _obterGeracoesAnteriores();
    final proximasGeracoes = _obterProximasGeracoes();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E5DC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 20),

            for (int i = geracoesAnteriores.length - 1; i >= 0; i--) ...[
              _buildGenerationTitle(
                icon: Icons.arrow_downward_rounded,
                title: _tituloGeracaoAnterior(i),
                subtitle:
                    '${geracoesAnteriores[i].length} '
                    '${geracoesAnteriores[i].length == 1 ? 'animal' : 'animais'}',
              ),

              const SizedBox(height: 12),

              _buildGenerationAnimals(
                context: context,
                animais: geracoesAnteriores[i],
              ),

              _buildConnectorDown(),

              const SizedBox(height: 4),
            ],

            _buildCurrentAnimal(),

            if (proximasGeracoes.isEmpty) ...[
              const SizedBox(height: 16),
              _buildNoChildren(),
            ],

            for (int i = 0; i < proximasGeracoes.length; i++) ...[
              _buildConnectorDown(),

              _buildGenerationTitle(
                icon: Icons.arrow_downward_rounded,
                title: _tituloProximaGeracao(i),
                subtitle:
                    '${proximasGeracoes[i].length} '
                    '${proximasGeracoes[i].length == 1 ? 'animal' : 'animais'}',
              ),

              const SizedBox(height: 12),

              _buildGenerationAnimals(
                context: context,
                animais: proximasGeracoes[i],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_tree_outlined,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Árvore familiar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Linhagem e gerações do animal',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerationTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerationAnimals({
    required BuildContext context,
    required List<Animal> animais,
  }) {
    if (animais.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < animais.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            SizedBox(
              width: 190,
              child: _buildAnimalCard(
                context: context,
                animal: animais[i],
                titulo: _tituloAnimalNaGeracao(animais[i], i),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _tituloAnimalNaGeracao(Animal animal, int indice) {
    switch (animal.sexo) {
      case SexoAnimal.femea:
        return 'Fêmea ${indice + 1}';

      case SexoAnimal.macho:
        return 'Macho ${indice + 1}';
    }
  }

  Widget _buildCurrentAnimal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          AnimalPhoto(fotoPath: animal.fotoPath, size: 64, borderRadius: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'ATUAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _nomeAnimal(animal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Brinco ${animal.brinco}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  '${animal.raca} • ${_sexoTexto(animal)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Icon(Icons.pets_rounded, color: AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _buildAnimalCard({
    required BuildContext context,
    required Animal animal,
    required String titulo,
  }) {
    final sexoCor = _sexoCor(animal);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AnimalDetailsPage(animal: animal, animais: animais),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E5DC)),
          ),
          child: Row(
            children: [
              AnimalPhoto(
                fotoPath: animal.fotoPath,
                size: 50,
                borderRadius: 12,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nomeAnimal(animal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Brinco ${animal.brinco}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      animal.raca,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: sexoCor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  animal.sexo == SexoAnimal.femea ? 'F' : 'M',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: sexoCor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorDown() {
    return Center(
      child: Container(
        width: 2,
        height: 22,
        color: AppTheme.primaryColor.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _buildNoChildren() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Nenhum descendente cadastrado até o momento.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
