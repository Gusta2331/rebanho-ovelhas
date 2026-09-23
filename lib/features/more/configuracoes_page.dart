import 'package:flutter/material.dart';

import '../../core/offline/connectivity_service.dart';
import '../../core/offline/offline_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/contextual_help.dart';
import '../auth/services/auth_service.dart';
import '../farm/models/farm.dart';
import '../farm/services/farm_service.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  final _farmService = FarmService();
  final _authService = AuthService();
  final _offlineSync = OfflineSyncService.instance;

  Farm? _farm;
  int _pendentes = 0;
  bool _carregando = true;
  bool _sincronizando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final resultados = await Future.wait([
        _farmService.getMinhaFazenda(),
        _offlineSync.pendentes(),
      ]);
      if (!mounted) return;
      setState(() {
        _farm = resultados[0] as Farm?;
        _pendentes = (resultados[1] as List).length;
        _erro = null;
        _carregando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _erro = error.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    try {
      await _offlineSync.sincronizar();
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _pendentes == 0
                ? 'Tudo sincronizado.'
                : '$_pendentes operação(ões) aguardando conexão ou correção.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Future<void> _editarFazenda() async {
    final farm = _farm;
    if (farm == null) return;
    final resultado = await showModalBottomSheet<Farm>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FarmEditor(farm: farm, service: _farmService),
    );
    if (resultado != null && mounted) setState(() => _farm = resultado);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: const [
          ContextualHelpButton(
            title: 'Configurações',
            introduction: 'Consulte a conta conectada, os dados principais da fazenda e o estado da sincronização.',
            topics: [
              HelpTopic(
                title: 'Conta',
                description: 'Mostra qual conta está conectada ao aplicativo.',
              ),
              HelpTopic(
                title: 'Fazenda',
                description: 'Revise os dados cadastrados para manter a identificação da propriedade atualizada.',
              ),
              HelpTopic(
                title: 'Sincronização',
                description: 'Quando há operações pendentes, mantenha a internet disponível e tente sincronizar novamente.',
              ),
              HelpTopic(
                title: 'Uso sem internet',
                description: 'Alguns registros podem ficar aguardando sincronização. Confira esta tela para ver se ainda há itens pendentes.',
              ),
            ],
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _secao('Conta'),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: const Text('Conta conectada'),
                      subtitle: Text(
                        _authService.currentUser?.email ??
                            'Sem e-mail disponível',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _secao('Fazenda'),
                  if (_erro != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(_erro!),
                      ),
                    )
                  else if (_farm == null)
                    const Card(
                      child: ListTile(
                        title: Text('Nenhuma fazenda encontrada'),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.agriculture_outlined),
                            ),
                            title: Text(_farm!.nome),
                            subtitle: Text(
                              [
                                    if ((_farm!.cidade ?? '').isNotEmpty)
                                      _farm!.cidade,
                                    if ((_farm!.estado ?? '').isNotEmpty)
                                      _farm!.estado,
                                  ].whereType<String>().join(' · ').isEmpty
                                  ? 'Dados da fazenda'
                                  : [
                                      if ((_farm!.cidade ?? '').isNotEmpty)
                                        _farm!.cidade,
                                      if ((_farm!.estado ?? '').isNotEmpty)
                                        _farm!.estado,
                                    ].whereType<String>().join(' · '),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.edit_outlined),
                            title: const Text('Editar dados da fazenda'),
                            trailing: const Icon(Icons.chevron_right),
                            enabled: ConnectivityService.instance.isOnline,
                            onTap: _editarFazenda,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  _secao('Conexão e sincronização'),
                  StreamBuilder<bool>(
                    stream: ConnectivityService.instance.statusStream,
                    initialData: ConnectivityService.instance.isOnline,
                    builder: (context, snapshot) {
                      final online = snapshot.data ?? false;
                      return Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                online
                                    ? Icons.cloud_done_outlined
                                    : Icons.cloud_off_outlined,
                                color: online
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                              ),
                              title: Text(
                                online ? 'Conectado' : 'Sem internet',
                              ),
                              subtitle: Text(
                                _pendentes == 0
                                    ? 'Nenhuma operação pendente'
                                    : '$_pendentes operação(ões) na fila',
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.sync),
                              title: const Text('Sincronizar agora'),
                              trailing: _sincronizando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right),
                              enabled: online && !_sincronizando,
                              onTap: _sincronizar,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Text(
                      'OviGestão · Fazenda Baixinha',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _secao(String titulo) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      titulo,
      style: const TextStyle(
        color: AppTheme.primaryColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _FarmEditor extends StatefulWidget {
  const _FarmEditor({required this.farm, required this.service});

  final Farm farm;
  final FarmService service;

  @override
  State<_FarmEditor> createState() => _FarmEditorState();
}

class _FarmEditorState extends State<_FarmEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.farm.nome);
  late final _cidade = TextEditingController(text: widget.farm.cidade);
  late final _estado = TextEditingController(text: widget.farm.estado);
  late final _telefone = TextEditingController(text: widget.farm.telefone);
  late final _endereco = TextEditingController(text: widget.farm.endereco);
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _cidade.dispose();
    _estado.dispose();
    _telefone.dispose();
    _endereco.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final farm = await widget.service.atualizarFazenda(
        id: widget.farm.id,
        nome: _nome.text,
        cidade: _cidade.text,
        estado: _estado.text,
        telefone: _telefone.text,
        endereco: _endereco.text,
      );
      if (mounted) Navigator.of(context).pop(farm);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dados da fazenda',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nome,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Informe o nome da fazenda.'
                    : null,
              ),
              TextFormField(
                controller: _cidade,
                decoration: const InputDecoration(labelText: 'Cidade'),
              ),
              TextFormField(
                controller: _estado,
                decoration: const InputDecoration(labelText: 'Estado'),
              ),
              TextFormField(
                controller: _telefone,
                decoration: const InputDecoration(labelText: 'Telefone'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _endereco,
                decoration: const InputDecoration(labelText: 'Endereço'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Salvar alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
