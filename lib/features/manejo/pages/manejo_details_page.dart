import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/manejo.dart';
import '../services/manejo_service.dart';

class ManejoDetailsPage extends StatefulWidget {
  final String manejoId;

  const ManejoDetailsPage({
    super.key,
    required this.manejoId,
  });

  @override
  State<ManejoDetailsPage> createState() => _ManejoDetailsPageState();
}

class _ManejoDetailsPageState extends State<ManejoDetailsPage> {
  final ManejoService _service = ManejoService();

  Map<String, dynamic>? _registro;
  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _historicoFamacha = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final registro = await _service.getManejo(widget.manejoId);
      final manejo = Manejo.fromMap(registro);
      final historico = await _service.getHistoricoFamacha(manejo.animalId);
      if (!mounted) return;
      setState(() {
        _registro = registro;
        _historicoFamacha = historico;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _tipo(TipoManejo tipo) {
    switch (tipo) {
      case TipoManejo.vacinacao:
        return 'Vacinação';
      case TipoManejo.vermifugacao:
        return 'Vermifugação';
      case TipoManejo.tratamento:
        return 'Tratamento';
      case TipoManejo.tosquia:
        return 'Tosquia';
      case TipoManejo.pesagem:
        return 'Pesagem';
      case TipoManejo.famacha:
        return 'FAMACHA';
      case TipoManejo.outro:
        return 'Outro';
    }
  }

  String _data(dynamic valor) {
    final data = DateTime.tryParse(valor?.toString() ?? '');
    if (data == null) return 'Não informada';
    return data.day.toString().padLeft(2, '0') +
        '/' +
        data.month.toString().padLeft(2, '0') +
        '/' +
        data.year.toString();
  }

  String _animal() {
    final animal = _registro?['animais'];
    if (animal is! Map) return 'Animal não encontrado';

    final brinco = animal['brinco']?.toString() ?? '';
    final nome = animal['nome']?.toString().trim();

    if (nome != null && nome.isNotEmpty) {
      return brinco + ' • ' + nome;
    }

    return 'Brinco ' + brinco;
  }

  @override
  Widget build(BuildContext context) {
    final registro = _registro;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do manejo')),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _erro!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : registro == null
                  ? const Center(child: Text('Manejo não encontrado.'))
                  : _conteudo(registro),
    );
  }

  Widget _conteudo(Map<String, dynamic> registro) {
    final manejo = Manejo.fromMap(registro);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(
                manejo.tipo == TipoManejo.famacha
                    ? Icons.visibility_outlined
                    : Icons.assignment_outlined,
                color: AppTheme.primaryColor,
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                manejo.tipo == TipoManejo.outro && manejo.outroNome != null
                    ? manejo.outroNome!
                    : _tipo(manejo.tipo),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _animal(),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _item('Data', _data(registro['data']), Icons.calendar_today_outlined),
        if (manejo.tipo == TipoManejo.famacha &&
            manejo.famachaEscore != null)
          _item(
            'Escore FAMACHA',
            manejo.famachaEscore.toString(),
            Icons.visibility_outlined,
          ),
        if (manejo.tipo == TipoManejo.outro && manejo.outroNome != null)
          _item(
            'Tipo de manejo',
            manejo.outroNome!,
            Icons.edit_note_outlined,
          ),
        if (manejo.tipo == TipoManejo.vacinacao &&
            manejo.vacinaNome != null)
          _item(
            'Vacina',
            manejo.vacinaFabricante == null ||
                    manejo.vacinaFabricante!.trim().isEmpty
                ? manejo.vacinaNome!
                : manejo.vacinaNome! + ' • ' + manejo.vacinaFabricante!,
            Icons.vaccines_outlined,
          ),
        if (manejo.tipo == TipoManejo.vacinacao &&
            manejo.vacinaLote != null &&
            manejo.vacinaLote!.trim().isNotEmpty)
          _item(
            'Lote',
            manejo.vacinaLote!,
            Icons.qr_code_2_outlined,
          ),
        if (manejo.observacoes != null)
          _item(
            'Observações',
            manejo.observacoes!,
            Icons.notes_outlined,
          ),
        if (manejo.tipo == TipoManejo.famacha &&
            _historicoFamacha.isNotEmpty)
          _historicoFamachaWidget(),
      ],
    );
  }


  Widget _historicoFamachaWidget() {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.history,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 8),
                Text(
                  'Histórico FAMACHA do animal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._historicoFamacha.take(8).map((registro) {
              final manejo = Manejo.fromMap(registro);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.10),
                  child: Text(
                    'F' + (manejo.famachaEscore?.toString() ?? '-'),
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(_data(registro['data'])),
                subtitle: manejo.observacoes == null
                    ? null
                    : Text(manejo.observacoes!),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _item(String titulo, String valor, IconData icone) {
    return Card(
      child: ListTile(
        leading: Icon(icone, color: AppTheme.primaryColor),
        title: Text(
          titulo,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
