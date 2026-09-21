import 'package:flutter/material.dart';

import '../../animals/services/animal_service.dart';
import '../models/monta.dart';
import '../services/reproducao_service.dart';

class MontaFormPage extends StatefulWidget {
  final String reproducaoId;
  final Monta? monta;
  const MontaFormPage({super.key, required this.reproducaoId, this.monta});
  @override
  State<MontaFormPage> createState() => _MontaFormPageState();
}

class _MontaFormPageState extends State<MontaFormPage> {
  final _service = ReproducaoService();
  final _animals = AnimalService();
  final _obs = TextEditingController();
  List<Map<String, dynamic>> _machos = [];
  String? _carneiroId;
  DateTime? _data;
  bool _loading = true, _saving = false;
  @override
  void initState() {
    super.initState();
    _carneiroId = widget.monta?.carneiroId;
    _data = widget.monta?.dataMonta;
    _obs.text = widget.monta?.observacoes ?? '';
    _load();
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final a = await _animals.getTodosAnimais();
      if (!mounted) return;
      setState(() => _machos = a.where((x) => x['sexo'] == 'macho').toList());
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(_msg(e), true);
      }
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

  void _snack(String s, bool err) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(s), backgroundColor: err ? Colors.red : null),
      );
  }

  Future<void> _save() async {
    if (_carneiroId == null) {
      _snack('Selecione o carneiro.', true);
      return;
    }
    if (_data == null) {
      _snack('Informe a data da monta.', true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.monta == null) {
        await _service.criarMonta(
          reproducaoId: widget.reproducaoId,
          carneiroId: _carneiroId!,
          dataMonta: _data!,
          observacoes: _obs.text,
        );
      } else {
        await _service.atualizarMonta(
          montaId: widget.monta!.id,
          reproducaoId: widget.reproducaoId,
          carneiroId: _carneiroId!,
          dataMonta: _data!,
          observacoes: _obs.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack(_msg(e), true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.monta == null ? 'Nova monta' : 'Editar monta'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _carneiroId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Carneiro *',
                      prefixIcon: Icon(Icons.male),
                    ),
                    items: _machos
                        .map(
                          (a) => DropdownMenuItem(
                            value: a['id'].toString(),
                            child: Text(
                              _animal(a),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _carneiroId = v),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _data ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: const Locale('pt', 'BR'),
                      );
                      if (d != null && mounted) setState(() => _data = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data da monta *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _data == null
                            ? 'Selecionar data'
                            : '${_data!.day.toString().padLeft(2, '0')}/${_data!.month.toString().padLeft(2, '0')}/${_data!.year}',
                      ),
                    ),
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
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ),
      ),
    );
  }
}
