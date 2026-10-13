/// Regras puras para identificar o próximo número de brinco disponível.
///
/// Todos os animais informados contam como números já usados, inclusive os
/// vendidos, mortos ou descartados. O histórico nunca deve liberar um brinco
/// para reutilização.
int menorBrincoDisponivel(Iterable<dynamic> animais) {
  final brincosUsados = <int>{};

  for (final animal in animais) {
    if (animal is! Map) continue;

    final brinco = animal['brinco'];
    if (brinco is int) {
      brincosUsados.add(brinco);
    } else if (brinco is num) {
      brincosUsados.add(brinco.toInt());
    } else if (brinco is String) {
      final numero = int.tryParse(brinco.trim());
      if (numero != null) brincosUsados.add(numero);
    }
  }

  var numero = 1;
  while (brincosUsados.contains(numero)) {
    numero++;
  }
  return numero;
}
