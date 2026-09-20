class Raca {
  final String id;
  final String nome;

  const Raca({required this.id, required this.nome});
}

class RacasData {
  static final List<Raca> racas = [
    const Raca(id: '1', nome: 'Santa Inês'),
    const Raca(id: '2', nome: 'Dorper'),
    const Raca(id: '3', nome: 'White Dorper'),
    const Raca(id: '4', nome: 'Somalis'),
    const Raca(id: '5', nome: 'Morada Nova'),
  ];
}
