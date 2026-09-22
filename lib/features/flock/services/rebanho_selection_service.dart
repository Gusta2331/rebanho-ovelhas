import 'package:flutter/foundation.dart';

import '../models/rebanho.dart';

class RebanhoSelectionService extends ChangeNotifier {
  RebanhoSelectionService._();

  static final RebanhoSelectionService instance = RebanhoSelectionService._();

  Rebanho? _rebanhoSelecionado;

  Rebanho? get rebanhoSelecionado => _rebanhoSelecionado;

  String? get rebanhoSelecionadoId => _rebanhoSelecionado?.id;

  void selecionar(Rebanho rebanho) {
    if (_rebanhoSelecionado?.id == rebanho.id) {
      return;
    }

    _rebanhoSelecionado = rebanho;
    notifyListeners();
  }

  void limpar() {
    if (_rebanhoSelecionado == null) {
      return;
    }

    _rebanhoSelecionado = null;
    notifyListeners();
  }

  bool estaSelecionado(String rebanhoId) {
    return _rebanhoSelecionado?.id == rebanhoId;
  }
}
