import '../models/animal.dart';

enum FaixaIdade {
  todas,
  ateSeisMeses,
  seisAdozeMeses,
  umADoisAnos,
  doisAnosOuMais,
}

class AnimalFilters {
  static int idadeEmMeses(DateTime nascimento) {
    final hoje = DateTime.now();

    int meses =
        (hoje.year - nascimento.year) * 12 + hoje.month - nascimento.month;

    if (hoje.day < nascimento.day) {
      meses--;
    }

    return meses < 0 ? 0 : meses;
  }

  static bool pertenceFaixaIdade(Animal animal, FaixaIdade faixa) {
    if (faixa == FaixaIdade.todas) {
      return true;
    }

    final nascimento = animal.dataNascimento;

    if (nascimento == null) {
      return false;
    }

    final meses = idadeEmMeses(nascimento);

    switch (faixa) {
      case FaixaIdade.todas:
        return true;

      case FaixaIdade.ateSeisMeses:
        return meses <= 6;

      case FaixaIdade.seisAdozeMeses:
        return meses > 6 && meses <= 12;

      case FaixaIdade.umADoisAnos:
        return meses > 12 && meses <= 24;

      case FaixaIdade.doisAnosOuMais:
        return meses > 24;
    }
  }

  static String nomeFaixaIdade(FaixaIdade faixa) {
    switch (faixa) {
      case FaixaIdade.todas:
        return 'Todas';

      case FaixaIdade.ateSeisMeses:
        return '0–6 meses';

      case FaixaIdade.seisAdozeMeses:
        return '6–12 meses';

      case FaixaIdade.umADoisAnos:
        return '1–2 anos';

      case FaixaIdade.doisAnosOuMais:
        return '2+ anos';
    }
  }
}
