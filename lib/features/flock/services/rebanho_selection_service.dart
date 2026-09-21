import '../models/rebanho.dart';

class RebanhoSelectionService {
  RebanhoSelectionService._();

  static final RebanhoSelectionService instance = RebanhoSelectionService._();

  Rebanho? _rebanhoSelecionado;

  Rebanho? get rebanhoSelecionado => _rebanhoSelecionado;

  String? get rebanhoSelecionadoId => _rebanhoSelecionado?.id;

  void selecionar(Rebanho rebanho) {
    _rebanhoSelecionado = rebanho;
  }

  void limpar() {
    _rebanhoSelecionado = null;
  }

  bool estaSelecionado(String rebanhoId) {
    return _rebanhoSelecionado?.id == rebanhoId;
  }
}
