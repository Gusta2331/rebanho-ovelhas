import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/contextual_help.dart';
import '../services/admin_producers_service.dart';

class AdminProducersPage extends StatefulWidget {
  const AdminProducersPage({super.key});

  @override
  State<AdminProducersPage> createState() => _AdminProducersPageState();
}

class _AdminProducersPageState extends State<AdminProducersPage> {
  final _service = AdminProducersService();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> get _plans =>
      List<Map<String, dynamic>>.from(_data['plans'] as List? ?? const []);
  List<Map<String, dynamic>> get _producers =>
      List<Map<String, dynamic>>.from(_data['producers'] as List? ?? const []);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final result = await _service.listar();
      if (mounted)
        setState(() {
          _data = result;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Future<void> _createProducer() async {
    if (_plans.isEmpty) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateProducerDialog(
        plans: _plans,
        onCreate: (name, email, password, planId) => _service.criar(
          nome: name,
          email: email,
          senha: password,
          planoId: planId,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _changePlan(Map<String, dynamic> producer) async {
    if (_plans.isEmpty) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => _PlanPickerDialog(plans: _plans),
    );
    if (chosen == null) return;
    try {
      await _service.alterarPlano(
        usuarioId: producer['id'].toString(),
        planoId: chosen,
      );
      await _load();
      _message('Plano atualizado.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _setPrice(Map<String, dynamic> plan) async {
    final price = await showDialog<double>(
      context: context,
      builder: (_) => _PlanPriceDialog(current: plan['preco_mensal']),
    );
    if (price == null) return;
    try {
      await _service.definirPreco(planoId: plan['id'].toString(), preco: price);
      await _load();
      _message(
        'Preço salvo. A cobrança automática ainda precisa ser integrada.',
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _money(dynamic value) {
    final price = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (price == null) return 'Preço não definido';
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')} / mês';
  }

  void _message(String value) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  }

  String _planName(dynamic plan) {
    if (plan is! Map) return 'Sem plano atribuído';
    final details = plan['planos_produtor'];
    return details is Map
        ? details['nome']?.toString() ?? 'Plano atribuído'
        : 'Plano atribuído';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administração'),
      actions: [
        const ContextualHelpButton(
          title: 'Administração de produtores',
          introduction: 'Área restrita para criar contas de produtores e associar um plano por quantidade de animais.',
          topics: [
            HelpTopic(
              title: 'Criar conta',
              description: 'Informe nome, e-mail e uma senha inicial segura. O produtor poderá entrar com essas credenciais.',
            ),
            HelpTopic(
              title: 'Plano',
              description: 'A faixa escolhida limita o número de animais ativos. O plano fica pendente até o produtor cadastrar a fazenda.',
            ),
            HelpTopic(
              title: 'Cobrança',
              description: 'Esta tela administra contas e limites. A cobrança automática ainda depende da integração de pagamentos e dos preços definidos.',
            ),
            HelpTopic(
              title: 'Acesso',
              description: 'O servidor libera esta área somente para os e-mails configurados como administradores no Supabase.',
            ),
          ],
        ),
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading || _plans.isEmpty ? null : _createProducer,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Criar produtor'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 46),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  '${_producers.length} contas cadastradas',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_producers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Nenhuma conta de produtor encontrada.'),
                    ),
                  ),
                ..._producers.map((producer) {
                  final farms = List<Map<String, dynamic>>.from(
                    producer['fazendas'] as List? ?? const [],
                  );
                  return Card(
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        (producer['nome']?.toString().trim().isNotEmpty ??
                                false)
                            ? producer['nome'].toString()
                            : producer['email'].toString(),
                      ),
                      subtitle: Text(producer['email']?.toString() ?? ''),
                      children: [
                        if (farms.isEmpty)
                          const ListTile(
                            leading: Icon(Icons.info_outline),
                            title: Text('Fazenda ainda não cadastrada'),
                            subtitle: Text(
                              'O plano ficará aguardando a criação da fazenda.',
                            ),
                          ),
                        ...farms.map(
                          (farm) => ListTile(
                            leading: const Icon(Icons.agriculture_outlined),
                            title: Text(farm['nome']?.toString() ?? 'Fazenda'),
                            subtitle: Text(
                              '${farm['animais_ativos'] ?? 0} animais ativos • ${_planName(farm['plano'])}',
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _changePlan(producer),
                            icon: const Icon(Icons.tune),
                            label: const Text('Alterar plano'),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                const Text(
                  'Faixas disponíveis',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._plans.map(
                  (plan) => ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: Text(plan['nome'].toString()),
                    subtitle: Text(
                      plan['limite_animais'] == null
                          ? 'Limite personalizado'
                          : 'Até ${plan['limite_animais']} animais ativos',
                    ),
                    trailing: TextButton(
                      onPressed: () => _setPrice(plan),
                      child: Text(_money(plan['preco_mensal'])),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}

class _CreateProducerDialog extends StatefulWidget {
  const _CreateProducerDialog({required this.plans, required this.onCreate});
  final List<Map<String, dynamic>> plans;
  final Future<void> Function(String, String, String, String) onCreate;
  @override
  State<_CreateProducerDialog> createState() => _CreateProducerDialogState();
}

class _CreateProducerDialogState extends State<_CreateProducerDialog> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _plan;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Criar conta de produtor'),
    content: Form(
      key: _key,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome do produtor'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome.' : null,
            ),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Informe um e-mail válido.'
                  : null,
            ),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha inicial (mínimo 8 caracteres)',
              ),
              validator: (v) => (v == null || v.length < 8)
                  ? 'Use ao menos 8 caracteres.'
                  : null,
            ),
            DropdownButtonFormField<String>(
              value: _plan,
              decoration: const InputDecoration(labelText: 'Plano inicial'),
              items: widget.plans
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id'].toString(),
                      child: Text(p['nome'].toString()),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _plan = value),
              validator: (v) => v == null ? 'Escolha um plano.' : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Criar conta'),
      ),
    ],
  );
  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onCreate(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
        _plan!,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }
}

class _PlanPickerDialog extends StatefulWidget {
  const _PlanPickerDialog({required this.plans});
  final List<Map<String, dynamic>> plans;
  @override
  State<_PlanPickerDialog> createState() => _PlanPickerDialogState();
}

class _PlanPickerDialogState extends State<_PlanPickerDialog> {
  String? _plan;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Alterar plano'),
    content: DropdownButtonFormField<String>(
      value: _plan,
      items: widget.plans
          .map(
            (p) => DropdownMenuItem(
              value: p['id'].toString(),
              child: Text(p['nome'].toString()),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _plan = value),
      decoration: const InputDecoration(labelText: 'Plano'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _plan == null ? null : () => Navigator.pop(context, _plan),
        child: const Text('Salvar'),
      ),
    ],
  );
}

class _PlanPriceDialog extends StatefulWidget {
  const _PlanPriceDialog({required this.current});
  final dynamic current;
  @override
  State<_PlanPriceDialog> createState() => _PlanPriceDialogState();
}

class _PlanPriceDialogState extends State<_PlanPriceDialog> {
  late final TextEditingController _price;
  final _key = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    final value = widget.current;
    _price = TextEditingController(text: value?.toString() ?? '');
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Preço mensal do plano'),
    content: Form(
      key: _key,
      child: TextFormField(
        controller: _price,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          prefixText: 'R\$ ',
          labelText: 'Valor mensal',
        ),
        validator: (value) {
          final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
          return parsed == null || parsed < 0
              ? 'Informe um valor válido.'
              : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(
            context,
            double.parse(_price.text.replaceAll(',', '.')),
          );
        },
        child: const Text('Salvar preço'),
      ),
    ],
  );
}
