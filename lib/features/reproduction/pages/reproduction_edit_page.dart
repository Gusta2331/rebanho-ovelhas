import 'package:flutter/material.dart';

import '../../../core/widgets/contextual_help.dart';
import '../../animals/services/animal_service.dart';
import '../models/reproducao.dart';
import '../services/reproducao_service.dart';

class ReproductionEditPage extends StatefulWidget {
  final Reproducao reproducao;
  const ReproductionEditPage({super.key, required this.reproducao});
  @override
  State<ReproductionEditPage> createState() => _ReproductionEditPageState();
}

class _ReproductionEditPageState extends State<ReproductionEditPage> {
  final _service = ReproducaoService();
  final _animalService = AnimalService();
  final _obs = TextEditingController();
  List<Map<String, dynamic>> _femeas = [];
  List<Map<String, dynamic>> _machos = [];
  String? _maeId, _paiId;
  DateTime? _cobertura, _previsao, _confirmacaoPrenhez, _parto;
  late StatusReproducao _statusSelecionado;
  bool _carregando = true, _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final r = widget.reproducao;
    _maeId = r.maeId;
    _paiId = r.paiId;
    _cobertura = r.dataCobertura;
    _previsao = r.dataPrevisaoParto;
    _confirmacaoPrenhez = r.dataConfirmacaoPrenhez;
    _parto = r.dataParto;
    _statusSelecionado = r.status;
    _obs.text = r.observacoes ?? '';
    _carregar();
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final a = await _animalService.getTodosAnimais();
      if (!mounted) return;
      setState(() {
        _femeas = a
            .where(
              (x) =>
                  x['sexo'] == 'femea' &&
                  (x['status'] == 'ativo' || x['id'].toString() == _maeId),
            )
            .toList();
        _machos = a
            .where(
              (x) =>
                  x['sexo'] == 'macho' &&
                  (x['status'] == 'ativo' || x['id'].toString() == _paiId),
            )
            .toList();
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = _msg(e);
      });
    }
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  String _animal(Map<String, dynamic> a) {
    final b = a['brinco'];
    final id = b is num
        ? b.toInt().toString().padLeft(3, '0')
        : (b?.toString() ?? 'Sem brinco');
    final n = a['nome']?.toString().trim();
    return n == null || n.isEmpty ? 'Brinco $id' : '$id • $n';
  }

  String _nomeStatus(StatusReproducao s) {
    switch (s) {
      case StatusReproducao.planejada:
        return 'Planejada';
      case StatusReproducao.coberta:
        return 'Coberta';
      case StatusReproducao.prenhe:
        return 'Prenhe';
      case StatusReproducao.naoPrenhe:
        return 'Não prenhe';
      case StatusReproducao.abortou:
        return 'Abortou';
      case StatusReproducao.partoRealizado:
        return 'Parto realizado';
      case StatusReproducao.encerrada:
        return 'Encerrada';
    }
  }

  String _statusDb(StatusReproducao s) {
    switch (s) {
      case StatusReproducao.planejada:
        return 'planejada';
      case StatusReproducao.coberta:
        return 'coberta';
      case StatusReproducao.prenhe:
        return 'prenhe';
      case StatusReproducao.naoPrenhe:
        return 'nao_prenhe';
      case StatusReproducao.abortou:
        return 'abortou';
      case StatusReproducao.partoRealizado:
        return 'parto_realizado';
      case StatusReproducao.encerrada:
        return 'encerrada';
    }
  }

  String _data(DateTime? d) {
    if (d == null) return 'Selecionar data';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _selecionarConfirmacaoPrenhez() async {
    if (_cobertura == null) {
      _snack('Registre a cobertura antes de confirmar a prenhez.', true);
      return;
    }

    final data = await showDatePicker(
      context: context,
      initialDate: _confirmacaoPrenhez ?? DateTime.now(),
      firstDate: _cobertura!,
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );

    if (data != null && mounted) {
      setState(() => _confirmacaoPrenhez = data);
    }
  }

  Future<void> _salvar() async {
    if (_maeId == null) {
      _snack('Selecione a mãe.', true);
      return;
    }
    setState(() => _salvando = true);
    try {
      final r = await _service.atualizarReproducao(
        reproducaoId: widget.reproducao.id,
        maeId: _maeId!,
        paiId: _paiId,
        dataCobertura: _cobertura,
        dataPrevisaoParto: _previsao,
        dataConfirmacaoPrenhez: _confirmacaoPrenhez,
        dataParto: _parto,
        status: _statusDb(_statusSelecionado),
        observacoes: _obs.text,
      );
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) _snack(_msg(e), true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _snack(String s, bool erro) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(s), backgroundColor: erro ? Colors.red : null),
      );
  }

  Future<void> _dataPicker(String campo) async {
    DateTime? atual;
    if (campo == 'cobertura') {
      atual = _cobertura;
    } else if (campo == 'previsao') {
      atual = _previsao;
    } else if (campo == 'confirmacao') {
      atual = _confirmacaoPrenhez;
    } else {
      atual = _parto;
    }

    final d = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: campo == 'confirmacao'
          ? _cobertura!
          : DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );

    if (d == null || !mounted) return;

    setState(() {
      if (campo == 'cobertura') {
        _cobertura = d;
        _previsao ??= d.add(const Duration(days: 146));
        if (_statusSelecionado == StatusReproducao.planejada) {
          _statusSelecionado = StatusReproducao.coberta;
        }
      } else if (campo == 'previsao') {
        _previsao = d;
      } else if (campo == 'confirmacao') {
        _confirmacaoPrenhez = d;
      } else {
        _parto = d;
      }
    });
  }

  Widget _animalField(
    String title,
    String? value,
    List<Map<String, dynamic>> list,
    ValueChanged<String?> onChanged,
    IconData icon, {
    bool optional = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: title, prefixIcon: Icon(icon)),
      items: [
        if (optional)
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Pai não definido'),
          ),
        ...list.map(
          (a) => DropdownMenuItem(
            value: a['id'].toString(),
            child: Text(_animal(a), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _dateField(
    String title,
    DateTime? value,
    String campo,
    IconData icon,
  ) {
    return InkWell(
      onTap: () => _dataPicker(campo),
      child: InputDecorator(
        decoration: InputDecoration(labelText: title, prefixIcon: Icon(icon)),
        child: Text(
          _data(value),
          style: TextStyle(color: value == null ? Colors.grey.shade600 : null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar reprodução'),
        actions: const [
          ContextualHelpButton(
            title: 'Editar reprodução',
            introduction: 'Atualize os dados da estação reprodutiva sem perder os registros de montas ou nascimentos.',
            topics: [
              HelpTopic(
                title: 'Período e situação',
                description: 'Revise as datas e a situação para manter a previsão e o acompanhamento em dia.',
              ),
              HelpTopic(
                title: 'Histórico',
                description: 'As montas e os cordeiros cadastrados continuam associados a esta reprodução.',
              ),
            ],
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_erro!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _carregar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _animalField(
                    'Ovelha mãe *',
                    _maeId,
                    _femeas,
                    (v) => setState(() => _maeId = v),
                    Icons.female,
                  ),
                  const SizedBox(height: 16),
                  _animalField(
                    'Carneiro / pai',
                    _paiId,
                    _machos,
                    (v) => setState(() => _paiId = v),
                    Icons.male,
                    optional: true,
                  ),
                  const SizedBox(height: 16),
                  _dateField(
                    'Data da cobertura',
                    _cobertura,
                    'cobertura',
                    Icons.calendar_today,
                  ),
                  const SizedBox(height: 16),
                  _dateField(
                    'Previsão de parto',
                    _previsao,
                    'previsao',
                    Icons.event,
                  ),
                  const SizedBox(height: 16),
                  _dateField(
                    'Data do parto',
                    _parto,
                    'parto',
                    Icons.child_friendly,
                  ),
                  const SizedBox(height: 16),
                  if (_statusSelecionado == StatusReproducao.prenhe ||
                      _confirmacaoPrenhez != null) ...[
                  _dateField(
                    'Data da confirmação da prenhez',
                    _confirmacaoPrenhez,
                    'confirmacao',
                    Icons.verified_outlined,
                  ),
                  const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<StatusReproducao>(
                    initialValue: _statusSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: StatusReproducao.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(_nomeStatus(s)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _statusSelecionado = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _obs,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_salvando ? 'Salvando...' : 'Salvar alterações'),
          ),
        ),
      ),
    );
  }
}
