import '../models/animal.dart';

enum FaixaIdade {
  todas,
  ateSeisMeses,
  seisAdozeMeses,
  umADoisAnos,
  doisAnosOuMais,
}

enum FiltroDataNascimento { todas, semData, comData }

enum FiltroDenticao {
  todas,
  leite,
  doisDentes,
  quatroDentes,
  seisDentes,
  bocaCheia,
  desgastada,
  outra,
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


extension FiltroDataNascimentoLabel on FiltroDataNascimento {
  String get label {
    switch (this) {
      case FiltroDataNascimento.todas: return 'Todas';
      case FiltroDataNascimento.semData: return 'Sem nascimento';
      case FiltroDataNascimento.comData: return 'Com nascimento';
    }
  }
}

extension FiltroDenticaoLabel on FiltroDenticao {
  String get label {
    switch (this) {
      case FiltroDenticao.todas: return 'Todas';
      case FiltroDenticao.leite: return 'Leite';
      case FiltroDenticao.doisDentes: return '2 dentes';
      case FiltroDenticao.quatroDentes: return '4 dentes';
      case FiltroDenticao.seisDentes: return '6 dentes';
      case FiltroDenticao.bocaCheia: return 'Boca cheia';
      case FiltroDenticao.desgastada: return 'Desgastada';
      case FiltroDenticao.outra: return 'Outra';
    }
  }

  String? get valorBanco {
    switch (this) {
      case FiltroDenticao.todas: return null;
      case FiltroDenticao.leite: return 'leite';
      case FiltroDenticao.doisDentes: return '2 dentes';
      case FiltroDenticao.quatroDentes: return '4 dentes';
      case FiltroDenticao.seisDentes: return '6 dentes';
      case FiltroDenticao.bocaCheia: return 'boca cheia';
      case FiltroDenticao.desgastada: return 'desgastada';
      case FiltroDenticao.outra: return 'outro';
    }
  }
}
