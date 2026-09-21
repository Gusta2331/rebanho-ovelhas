import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../services/animal_transfer_service.dart';

class AnimalTransferPage extends StatefulWidget {
  final String animalId;
  final String brinco;
  final String rebanhoAtualId;
  final String rebanhoAtualNome;

  const AnimalTransferPage({
    super.key,
    required this.animalId,
    required this.brinco,
    required this.rebanhoAtualId,
    required this.rebanhoAtualNome,
  });

  @override
  State<AnimalTransferPage> createState() => _AnimalTransferPageState();
}

class _AnimalTransferPageState extends State<AnimalTransferPage> {
  final AnimalTransferService _transferService = AnimalTransferService();

  final TextEditingController _observacaoController = TextEditingController();

  List<Map<String, dynamic>> _rebanhos = [];

  String? _rebanhoSelecionadoId;

  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarRebanhos();
  }

  @override
  void dispose() {
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarRebanhos() async {
    setState(() {
      _carregando = true;
    });

    try {
      final rebanhos = await _transferService.getRebanhosDisponiveis(
        rebanhoAtualId: widget.rebanhoAtualId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _rebanhos = rebanhos;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
      });

      _mostrarErro('Não foi possível carregar os rebanhos.', e);
    }
  }

  Future<void> _transferir() async {
    final destinoId = _rebanhoSelecionadoId;

    if (destinoId == null) {
      _mostrarMensagem('Selecione o rebanho de destino.');
      return;
    }

    final destino = _rebanhos.firstWhere(
      (rebanho) => rebanho['id'].toString() == destinoId,
    );

    final destinoNome = destino['nome']?.toString() ?? 'Rebanho';

    final confirmou = await _confirmarTransferencia(destinoNome);

    if (!confirmou || !mounted) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      await _transferService.transferirAnimal(
        animalId: widget.animalId,
        rebanhoOrigemId: widget.rebanhoAtualId,
        rebanhoDestinoId: destinoId,
        observacao: _observacaoController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _salvando = false;
      });

      _mostrarErro('Não foi possível transferir o animal.', e);
    }
  }

  Future<bool> _confirmarTransferencia(String destinoNome) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar transferência'),
          content: Text(
            'O animal ${widget.brinco} será transferido de '
            '${widget.rebanhoAtualNome} para $destinoNome.\n\n'
            'Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Transferir'),
            ),
          ],
        );
      },
    );

    return resultado ?? false;
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  void _mostrarErro(String mensagem, Object erro) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$mensagem\n$erro'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F5),
      appBar: AppBar(
        title: const Text('Transferir animal'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textColor,
        elevation: 0,
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_rebanhos.isEmpty) {
      return _buildSemRebanhos();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildAnimalCard(),
        const SizedBox(height: 20),
        _buildRebanhoAtual(),
        const SizedBox(height: 20),
        _buildDestino(),
        const SizedBox(height: 20),
        _buildObservacao(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildAnimalCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: AppTheme.primaryColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Animal',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 3),
                Text(
                  'Brinco ${widget.brinco}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRebanhoAtual() {
    return _buildSection(
      title: 'Rebanho atual',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.groups_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.rebanhoAtualNome,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestino() {
    return _buildSection(
      title: 'Novo rebanho',
      child: DropdownButtonFormField<String>(
        initialValue: _rebanhoSelecionadoId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Selecione o rebanho de destino',
          prefixIcon: const Icon(Icons.drive_file_move_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9DED5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
          ),
        ),
        items: _rebanhos.map((rebanho) {
          final id = rebanho['id'].toString();
          final nome = rebanho['nome']?.toString() ?? 'Rebanho';

          final quantidade = rebanho['quantidade_animais'];

          return DropdownMenuItem<String>(
            value: id,
            child: Text(
              quantidade is num
                  ? '$nome • ${quantidade.toInt()} animais'
                  : nome,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: _salvando
            ? null
            : (valor) {
                setState(() {
                  _rebanhoSelecionadoId = valor;
                });
              },
      ),
    );
  }

  Widget _buildObservacao() {
    return _buildSection(
      title: 'Observação',
      child: TextField(
        controller: _observacaoController,
        enabled: !_salvando,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Ex.: transferência para separar o lote...',
          alignLabelWithHint: true,
          prefixIcon: const Padding(
            padding: EdgeInsets.only(bottom: 55),
            child: Icon(Icons.notes_outlined),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9DED5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildSemRebanhos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum outro rebanho disponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie outro rebanho para poder transferir este animal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    if (_carregando || _rebanhos.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _salvando ? null : _transferir,
            icon: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.swap_horiz_rounded),
            label: Text(_salvando ? 'Transferindo...' : 'Transferir animal'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
