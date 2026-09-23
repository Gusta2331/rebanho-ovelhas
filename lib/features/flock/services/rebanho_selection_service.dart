import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rebanho.dart';

class RebanhoSelectionService extends ChangeNotifier {
  RebanhoSelectionService._();

  static final RebanhoSelectionService instance = RebanhoSelectionService._();

  Rebanho? _rebanhoSelecionado;

  Rebanho? get rebanhoSelecionado => _rebanhoSelecionado;

  String? get rebanhoSelecionadoId => _rebanhoSelecionado?.id;

  Future<void> restaurar() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('lote_selecionado_id');

    if (id == null || id.isEmpty) {
      return;
    }

    final nome = prefs.getString('lote_selecionado_nome');
    final descricao = prefs.getString('lote_selecionado_descricao');

    if (nome == null || nome.isEmpty) {
      return;
    }

    selecionar(
      Rebanho(
        id: id,
        fazendaId: prefs.getString('lote_selecionado_fazenda_id') ?? '',
        nome: nome,
        descricao: descricao,
        finalidade: prefs.getString('lote_selecionado_finalidade'),
        localizacao: prefs.getString('lote_selecionado_localizacao'),
        ativo: prefs.getBool('lote_selecionado_ativo') ?? true,
        quantidadeAnimais:
            prefs.getInt('lote_selecionado_quantidade') ?? 0,
      ),
    );
  }

  void selecionar(Rebanho rebanho) {
    if (_rebanhoSelecionado?.id == rebanho.id) {
      return;
    }

    _rebanhoSelecionado = rebanho;
    notifyListeners();
    _salvarSelecao(rebanho);
  }

  Future<void> _salvarSelecao(Rebanho rebanho) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lote_selecionado_id', rebanho.id);
    await prefs.setString('lote_selecionado_fazenda_id', rebanho.fazendaId);
    await prefs.setString('lote_selecionado_nome', rebanho.nome);
    await prefs.setString('lote_selecionado_descricao', rebanho.descricao ?? '');
    await prefs.setString('lote_selecionado_finalidade', rebanho.finalidade ?? '');
    await prefs.setString('lote_selecionado_localizacao', rebanho.localizacao ?? '');
    await prefs.setBool('lote_selecionado_ativo', rebanho.ativo);
    await prefs.setInt('lote_selecionado_quantidade', rebanho.quantidadeAnimais);
  }

  void limpar() {
    if (_rebanhoSelecionado == null) {
      return;
    }

    _rebanhoSelecionado = null;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('lote_selecionado_id');
      prefs.remove('lote_selecionado_fazenda_id');
      prefs.remove('lote_selecionado_nome');
      prefs.remove('lote_selecionado_descricao');
      prefs.remove('lote_selecionado_finalidade');
      prefs.remove('lote_selecionado_localizacao');
      prefs.remove('lote_selecionado_ativo');
      prefs.remove('lote_selecionado_quantidade');
    });
  }

  bool estaSelecionado(String rebanhoId) {
    return _rebanhoSelecionado?.id == rebanhoId;
  }
}
