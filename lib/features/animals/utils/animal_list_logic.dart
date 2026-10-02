import '../models/animal.dart';
import 'animal_filters.dart';

class AnimalListLogic {
  static List<Animal> porStatus(List<Animal> animais, StatusAnimal status) {
    return animais.where((animal) {
      return animal.status == status;
    }).toList();
  }

  static List<Animal> filtrar({
    required List<Animal> animais,
    required StatusAnimal status,
    required SexoAnimal? sexo,
    required FaixaIdade faixaIdade,
    required String busca,
  }) {
    var resultado = porStatus(animais, status);

    if (sexo != null) {
      resultado = resultado.where((animal) {
        return animal.sexo == sexo;
      }).toList();
    }

    if (faixaIdade != FaixaIdade.todas) {
      resultado = resultado.where((animal) {
        return AnimalFilters.pertenceFaixaIdade(animal, faixaIdade);
      }).toList();
    }

    if (busca.trim().isEmpty) {
      return resultado;
    }

    final texto = busca.trim().toLowerCase();

    return resultado.where((animal) {
      final brinco = animal.brinco.toLowerCase();
      final nome = animal.nome?.toLowerCase() ?? '';
      final raca = animal.raca.toLowerCase();

      return brinco.contains(texto) ||
          nome.contains(texto) ||
          raca.contains(texto);
    }).toList();
  }

  static int quantidadePorStatus(
    List<Animal> animais,
    StatusAnimal status, {
    SexoAnimal? sexo,
    FaixaIdade faixaIdade = FaixaIdade.todas,
    String busca = '',
  }) {
    return _baseFiltrada(
      animais,
      sexo: sexo,
      faixaIdade: faixaIdade,
      busca: busca,
    ).where((animal) => animal.status == status).length;
  }

  static int quantidadePorSexo(
    List<Animal> animais,
    StatusAnimal status,
    SexoAnimal sexo, {
    FaixaIdade faixaIdade = FaixaIdade.todas,
    String busca = '',
  }) {
    return _baseFiltrada(
      animais,
      status: status,
      faixaIdade: faixaIdade,
      busca: busca,
    ).where((animal) => animal.sexo == sexo).length;
  }

  static int quantidadePorFaixaIdade(
    List<Animal> animais,
    StatusAnimal status,
    FaixaIdade faixa,
    SexoAnimal? sexo, {
    String busca = '',
  }) {
    return _baseFiltrada(
      animais,
      status: status,
      sexo: sexo,
      busca: busca,
    ).where((animal) => AnimalFilters.pertenceFaixaIdade(animal, faixa)).length;
  }

  static List<Animal> _baseFiltrada(
    List<Animal> animais, {
    StatusAnimal? status,
    SexoAnimal? sexo,
    FaixaIdade faixaIdade = FaixaIdade.todas,
    String busca = '',
  }) {
    var resultado = animais;

    if (status != null) {
      resultado = resultado.where((animal) => animal.status == status).toList();
    }

    if (sexo != null) {
      resultado = resultado.where((animal) => animal.sexo == sexo).toList();
    }

    if (faixaIdade != FaixaIdade.todas) {
      resultado = resultado.where((animal) {
        return AnimalFilters.pertenceFaixaIdade(animal, faixaIdade);
      }).toList();
    }

    final texto = busca.trim().toLowerCase();

    if (texto.isEmpty) {
      return resultado;
    }

    return resultado.where((animal) {
      final brinco = animal.brinco.toLowerCase();
      final nome = animal.nome?.toLowerCase() ?? '';
      final raca = animal.raca.toLowerCase();

      return brinco.contains(texto) ||
          nome.contains(texto) ||
          raca.contains(texto);
    }).toList();
  }

  static String normalizarBrinco(String brinco) {
    final numero = int.tryParse(brinco.trim());

    if (numero != null) {
      return numero.toString();
    }

    return brinco.trim().toLowerCase();
  }
}
