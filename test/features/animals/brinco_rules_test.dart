import 'package:flutter_test/flutter_test.dart';
import 'package:ovigestao/features/animals/utils/brinco_rules.dart';

void main() {
  group('menorBrincoDisponivel', () {
    test('retorna 1 quando não existem animais', () {
      expect(menorBrincoDisponivel([]), 1);
    });

    test('retorna o menor número ainda não utilizado', () {
      final animais = [
        {'brinco': 1, 'status': 'ativo'},
        {'brinco': 2, 'status': 'ativo'},
        {'brinco': 4, 'status': 'ativo'},
      ];

      expect(menorBrincoDisponivel(animais), 3);
    });

    test('não reutiliza brincos de animais vendidos, mortos ou descartados', () {
      final animais = [
        {'brinco': 1, 'status': 'vendido'},
        {'brinco': 2, 'status': 'morto'},
        {'brinco': 3, 'status': 'descartado'},
        {'brinco': 4, 'status': 'ativo'},
      ];

      expect(menorBrincoDisponivel(animais), 5);
    });

    test('aceita números recebidos como inteiro, decimal numérico ou texto', () {
      final animais = [
        {'brinco': 1},
        {'brinco': 2.0},
        {'brinco': '3'},
      ];

      expect(menorBrincoDisponivel(animais), 4);
    });

    test('ignora registros sem brinco numérico válido', () {
      final animais = [
        {'nome': 'Sem brinco'},
        {'brinco': 'não numérico'},
        null,
      ];

      expect(menorBrincoDisponivel(animais), 1);
    });
  });
}
