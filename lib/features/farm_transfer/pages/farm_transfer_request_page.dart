import 'package:flutter/material.dart';

import '../../animals/models/animal.dart';
import '../services/farm_transfer_service.dart';

class FarmTransferRequestPage extends StatefulWidget {
  final Animal animal;
  final FarmTransferSaleData? sale;

  const FarmTransferRequestPage({super.key, required this.animal, this.sale});

  @override
  State<FarmTransferRequestPage> createState() =>
      _FarmTransferRequestPageState();
}

class _FarmTransferRequestPageState extends State<FarmTransferRequestPage> {
  final _service = FarmTransferService();
  final _codeController = TextEditingController();
  final _observationController = TextEditingController();
  Map<String, String>? _destination;
  bool _validating = false;
  bool _saving = false;

  @override
  void dispose() {
    _codeController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    setState(() {
      _validating = true;
      _destination = null;
    });
    try {
      final destination = await _service.findDestination(_codeController.text);
      if (!mounted) return;
      setState(() => _destination = destination);
      if (destination == null)
        _message('Código não encontrado. Confira e tente novamente.');
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _submit() async {
    final destination = _destination;
    if (destination == null) {
      _message('Valide o código da fazenda de destino antes de continuar.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar solicitação?'),
        content: Text(
          'O animal ${widget.animal.brinco} continuará na sua fazenda até que ${destination['nome']} aceite a solicitação.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.requestTransfer(
        animalId: widget.animal.id,
        destinationCode: _codeController.text,
        observation: _observationController.text,
        sale: widget.sale,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void _error(Object error) =>
      _message(error.toString().replaceFirst('Exception: ', ''));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.sale == null
            ? 'Transferir para outra fazenda'
            : 'Vender para outra fazenda',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.pets_outlined),
            title: Text('Brinco ${widget.animal.brinco}'),
            subtitle: Text(widget.animal.nome ?? 'Animal sem nome'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.sale == null
              ? 'A transferência só será concluída quando a outra fazenda aceitar. Até lá, o animal permanece nesta fazenda.'
              : 'A venda e a receita no financeiro só serão registradas quando a fazenda compradora aceitar. Até lá, o animal permanece nesta fazenda.',
        ),
        if (widget.sale != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(
                'Valor da venda: R\$ ${widget.sale!.totalValue.toStringAsFixed(2).replaceAll('.', ',')}',
              ),
              subtitle: Text(
                widget.sale!.saleType == 'por_kg'
                    ? 'Venda por kg'
                    : 'Venda por valor fechado',
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Código de recebimento da fazenda',
            hintText: 'Cole o código compartilhado pelo comprador',
            border: const OutlineInputBorder(),
            suffixIcon: _validating
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.verified_outlined),
                    tooltip: 'Validar código',
                    onPressed: _validate,
                  ),
          ),
          onChanged: (_) => setState(() => _destination = null),
        ),
        if (_destination != null) ...[
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.verified, color: Colors.green),
            title: Text(_destination!['nome']!),
            subtitle: const Text('Fazenda de destino confirmada'),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _observationController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observação (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: FilledButton.icon(
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_outlined),
        label: Text(
          _saving
              ? 'Enviando...'
              : widget.sale == null
              ? 'Enviar solicitação'
              : 'Enviar venda para aceite',
        ),
      ),
    ),
  );
}
