import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/rebanho.dart';
import '../services/rebanho_service.dart';
import '../widgets/rebanho_card.dart';
import 'rebanho_form_page.dart';
import 'rebanho_help_page.dart';

class RebanhosPage extends StatefulWidget {
  const RebanhosPage({super.key});

  @override
  State<RebanhosPage> createState() => _RebanhosPageState();
}

class _RebanhosPageState extends State<RebanhosPage> {
  final RebanhoService _rebanhoService = RebanhoService();

  List<Rebanho> _rebanhos = [];

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarRebanhos();
  }

  Future<void> _carregarRebanhos() async {
    try {
      final dados = await _rebanhoService.getRebanhos();

      final rebanhos = dados.map(Rebanho.fromMap).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _rebanhos = rebanhos;
        _carregando = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mensagemErro(error))));
    }
  }

  Future<void> _novoRebanho() async {
    final rebanho = await Navigator.of(context).push<Rebanho>(
      MaterialPageRoute(builder: (context) => const RebanhoFormPage()),
    );

    if (rebanho == null || !mounted) {
      return;
    }

    await _carregarRebanhos();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rebanho "${rebanho.nome}" criado com sucesso.')),
    );
  }

  Future<void> _editarRebanho(Rebanho rebanho) async {
    final rebanhoAtualizado = await Navigator.of(context).push<Rebanho>(
      MaterialPageRoute(
        builder: (context) => RebanhoFormPage(rebanhoParaEditar: rebanho),
      ),
    );

    if (rebanhoAtualizado == null || !mounted) {
      return;
    }

    await _carregarRebanhos();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rebanho atualizado com sucesso.')),
    );
  }

  Future<void> _alterarStatus(Rebanho rebanho) async {
    final novoStatus = !rebanho.ativo;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(novoStatus ? 'Ativar rebanho' : 'Inativar rebanho'),
          content: Text(
            novoStatus
                ? 'Deseja ativar o rebanho "${rebanho.nome}"?'
                : 'Deseja inativar o rebanho "${rebanho.nome}"?',
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
              child: Text(novoStatus ? 'Ativar' : 'Inativar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) {
      return;
    }

    try {
      await _rebanhoService.alterarStatus(id: rebanho.id, ativo: novoStatus);

      await _carregarRebanhos();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mensagemErro(error))));
    }
  }

  String _mensagemErro(Object error) {
    final mensagem = error.toString();

    if (mensagem.startsWith('Exception: ')) {
      return mensagem.substring('Exception: '.length);
    }

    return 'Não foi possível carregar os rebanhos.';
  }

  Future<void> _atualizar() async {
    setState(() {
      _carregando = true;
    });

    await _carregarRebanhos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rebanhos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RebanhoHelpPage(),
                ),
              );
            },
            tooltip: 'Ajuda',
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _atualizar, child: _buildBody()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoRebanho,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo rebanho'),
      ),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_rebanhos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 120),
        children: [
          Icon(
            Icons.pets_outlined,
            size: 72,
            color: AppTheme.primaryColor.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 18),
          const Text(
            'Nenhum rebanho cadastrado',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crie o primeiro rebanho para começar a organizar os animais da Fazenda Baixinha.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _novoRebanho,
              icon: const Icon(Icons.add),
              label: const Text('Criar primeiro rebanho'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      itemCount: _rebanhos.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        final rebanho = _rebanhos[index];

        return RebanhoCard(
          rebanho: rebanho,
          onTap: () {},
          onEditar: () {
            _editarRebanho(rebanho);
          },
          onAlterarStatus: () {
            _alterarStatus(rebanho);
          },
        );
      },
    );
  }
}
