import 'package:flutter/material.dart';

import '../../../core/widgets/contextual_help.dart';
import '../services/reproducao_service.dart';

class NascimentoFormPage extends StatefulWidget {
  final String reproducaoId;
  const NascimentoFormPage({super.key, required this.reproducaoId});
  @override
  State<NascimentoFormPage> createState() => _NascimentoFormPageState();
}

class _NascimentoFormPageState extends State<NascimentoFormPage> {
  final _service = ReproducaoService();
  final _nome = TextEditingController();
  final _obs = TextEditingController();
  String _sexo = 'femea';
  DateTime _data = DateTime.now();
  bool _saving = false;
  @override
  void dispose() {
    _nome.dispose();
    _obs.dispose();
    super.dispose();
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final n = await _service.registrarNascimentoNovoAnimal(
        reproducaoId: widget.reproducaoId,
        sexo: _sexo,
        dataNascimento: _data,
        nome: _nome.text,
        observacoes: _obs.text,
      );
      if (mounted) Navigator.pop(context, n);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_msg(e)), backgroundColor: Colors.red),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar nascimento'),
        actions: const [
          ContextualHelpButton(
            title: 'Registrar nascimento',
            introduction: 'Adicione um cordeiro nascido nesta reprodução.',
            topics: [
              HelpTopic(
                title: 'Identificação',
                description: 'Informe o brinco, nome e sexo do cordeiro para incluí-lo no rebanho.',
              ),
              HelpTopic(
                title: 'Data',
                description: 'Registre a data real do nascimento para manter o histórico correto.',
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'O sistema criará o cordeiro automaticamente, usando um brinco nunca utilizado e vinculando mãe e pai da reprodução.',
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _sexo,
              decoration: const InputDecoration(
                labelText: 'Sexo *',
                prefixIcon: Icon(Icons.pets_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'femea', child: Text('Fêmea')),
                DropdownMenuItem(value: 'macho', child: Text('Macho')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _sexo = v);
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _data,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  locale: const Locale('pt', 'BR'),
                );
                if (d != null && mounted) setState(() => _data = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data do nascimento *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  '${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nome,
              decoration: const InputDecoration(
                labelText: 'Nome do cordeiro',
                hintText: 'Opcional',
                prefixIcon: Icon(Icons.label_outline),
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
                : const Icon(Icons.child_friendly),
            label: Text(_saving ? 'Registrando...' : 'Registrar nascimento'),
          ),
        ),
      ),
    );
  }
}
