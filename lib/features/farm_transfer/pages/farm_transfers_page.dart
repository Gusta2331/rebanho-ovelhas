import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/farm_transfer.dart';
import '../services/farm_transfer_service.dart';

class FarmTransfersPage extends StatefulWidget {
  const FarmTransfersPage({super.key});

  @override
  State<FarmTransfersPage> createState() => _FarmTransfersPageState();
}

class _FarmTransfersPageState extends State<FarmTransfersPage> {
  final _service = FarmTransferService();
  late Future<_TransferData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TransferData> _load() async {
    final results = await Future.wait([
      _service.getMyReceivingCode(),
      _service.getReceived(),
      _service.getSent(),
    ]);
    return _TransferData(
      code: results[0] as String,
      received: results[1] as List<FarmTransfer>,
      sent: results[2] as List<FarmTransfer>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Código copiado.')));
  }

  Future<void> _respond(FarmTransfer transfer, bool accept) async {
    if (!accept) {
      final confirm = await _confirm(
        'Recusar solicitação?',
        'O animal continuará na fazenda de origem.',
      );
      if (confirm != true) return;
      await _runResponse(transfer, false);
      return;
    }
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _AcceptFarmTransferPage(transfer: transfer),
      ),
    );
    if (result == true && mounted) _refresh();
  }

  Future<void> _runResponse(FarmTransfer transfer, bool accept) async {
    try {
      await _service.respond(transferId: transfer.id, accept: accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Transferência aceita.' : 'Solicitação recusada.',
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );

  Future<void> _showHistory(FarmTransfer transfer) async {
    try {
      final history = await _service.getHistory(transfer.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Histórico da transferência'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: history
                  .map(
                    (entry) => ListTile(
                      title: Text(_eventLabel(entry.event)),
                      subtitle: Text(_date(entry.occurredAt)),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _eventLabel(String event) => switch (event) {
    'solicitada' => 'Solicitação enviada',
    'aceita' => 'Transferência aceita e concluída',
    'rejeitada' => 'Solicitação recusada',
    'cancelada' => 'Solicitação cancelada',
    _ => event,
  };

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Transferências entre fazendas')),
    body: FutureBuilder<_TransferData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _ErrorView(error: snapshot.error, onRetry: _refresh);
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                _ReceivingCode(code: data.code, onCopy: () => _copy(data.code)),
                const TabBar(
                  tabs: [
                    Tab(text: 'Recebidas'),
                    Tab(text: 'Enviadas'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TransferList(
                        transfers: data.received,
                        received: true,
                        onAccept: (t) => _respond(t, true),
                        onReject: (t) => _respond(t, false),
                        onHistory: _showHistory,
                        date: _date,
                      ),
                      _TransferList(
                        transfers: data.sent,
                        received: false,
                        onAccept: (_) {},
                        onReject: (_) {},
                        onHistory: _showHistory,
                        date: _date,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _TransferData {
  final String code;
  final List<FarmTransfer> received;
  final List<FarmTransfer> sent;
  const _TransferData({
    required this.code,
    required this.received,
    required this.sent,
  });
}

class _ReceivingCode extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  const _ReceivingCode({required this.code, required this.onCopy});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(12),
    child: ListTile(
      leading: const Icon(Icons.key_outlined),
      title: const Text('Seu código de recebimento'),
      subtitle: Text(code),
      trailing: IconButton(
        icon: const Icon(Icons.copy_outlined),
        tooltip: 'Copiar código',
        onPressed: onCopy,
      ),
    ),
  );
}

class _TransferList extends StatelessWidget {
  final List<FarmTransfer> transfers;
  final bool received;
  final ValueChanged<FarmTransfer> onAccept;
  final ValueChanged<FarmTransfer> onReject;
  final ValueChanged<FarmTransfer> onHistory;
  final String Function(DateTime) date;
  const _TransferList({
    required this.transfers,
    required this.received,
    required this.onAccept,
    required this.onReject,
    required this.onHistory,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty)
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Text(
              received
                  ? 'Nenhuma solicitação recebida.'
                  : 'Nenhuma solicitação enviada.',
            ),
          ),
        ],
      );
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: transfers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final t = transfers[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brinco ${t.originTag} · ${t.animalName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  received
                      ? 'De: ${t.farmOriginName}'
                      : 'Para: ${t.farmDestinationName}',
                ),
                if (t.operationType == 'venda' && t.saleValue != null)
                  Text(
                    'Venda: R\$ ${t.saleValue!.toStringAsFixed(2).replaceAll('.', ',')}',
                  ),
                Text('Solicitada em ${date(t.requestedAt)}'),
                if (t.observation?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(t.observation!),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(_status(t.status))),
                    OutlinedButton.icon(
                      onPressed: () => onHistory(t),
                      icon: const Icon(Icons.history_outlined),
                      label: const Text('Histórico'),
                    ),
                    if (received && t.isPending) ...[
                      OutlinedButton(
                        onPressed: () => onReject(t),
                        child: const Text('Recusar'),
                      ),
                      FilledButton(
                        onPressed: () => onAccept(t),
                        child: const Text('Aceitar'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _status(String status) => switch (status) {
    'pendente' => 'Pendente',
    'aceita' => 'Aceita',
    'rejeitada' => 'Recusada',
    'cancelada' => 'Cancelada',
    _ => status,
  };
}

class _AcceptFarmTransferPage extends StatefulWidget {
  final FarmTransfer transfer;
  const _AcceptFarmTransferPage({required this.transfer});
  @override
  State<_AcceptFarmTransferPage> createState() =>
      _AcceptFarmTransferPageState();
}

class _AcceptFarmTransferPageState extends State<_AcceptFarmTransferPage> {
  final _service = FarmTransferService();
  final _tagController = TextEditingController();
  List<Map<String, dynamic>> _flocks = [];
  String? _flockId;
  bool _loading = true;
  bool _conflict = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getDestinationFlocks(),
        _service.hasTagConflict(widget.transfer.originTag),
      ]);
      if (!mounted) return;
      setState(() {
        _flocks = results[0] as List<Map<String, dynamic>>;
        _conflict = results[1] as bool;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    if (_flockId == null) {
      _message('Selecione o lote de destino.');
      return;
    }
    final newTag = int.tryParse(_tagController.text.trim());
    if (_conflict && newTag == null) {
      _message(
        'O brinco ${widget.transfer.originTag} já existe nesta fazenda. Informe um novo brinco.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.respond(
        transferId: widget.transfer.id,
        accept: true,
        destinationFlockId: _flockId,
        newTag: newTag,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aceitar transferência')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Animal: brinco ${widget.transfer.originTag} · ${widget.transfer.animalName}',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: _flockId,
                decoration: const InputDecoration(
                  labelText: 'Lote de destino',
                  border: OutlineInputBorder(),
                ),
                items: _flocks
                    .map(
                      (f) => DropdownMenuItem(
                        value: f['id'].toString(),
                        child: Text(f['nome']?.toString() ?? 'Lote'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _flockId = value),
              ),
              const SizedBox(height: 16),
              if (_conflict) ...[
                const Text(
                  'Este brinco já foi usado nesta fazenda, inclusive em animais inativos. Escolha outro antes de aceitar.',
                  style: TextStyle(color: Colors.deepOrange),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _tagController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _conflict
                      ? 'Novo brinco (obrigatório)'
                      : 'Novo brinco (opcional)',
                  hintText: _conflict
                      ? null
                      : 'Mantenha vazio para usar ${widget.transfer.originTag}',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A confirmação transfere a propriedade no servidor. Não é possível concluir esta operação sem internet.',
              ),
            ],
          ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: FilledButton(
        onPressed: _saving || _loading ? null : _accept,
        child: Text(_saving ? 'Concluindo...' : 'Confirmar recebimento'),
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error.toString().replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
