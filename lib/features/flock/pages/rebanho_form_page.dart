import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/contextual_help.dart';
import '../models/rebanho.dart';
import '../services/rebanho_service.dart';

class RebanhoFormPage extends StatefulWidget {
  final Rebanho? rebanhoParaEditar;

  const RebanhoFormPage({super.key, this.rebanhoParaEditar});

  @override
  State<RebanhoFormPage> createState() => _RebanhoFormPageState();
}

class _RebanhoFormPageState extends State<RebanhoFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _finalidadeController = TextEditingController();
  final _localizacaoController = TextEditingController();

  final RebanhoService _rebanhoService = RebanhoService();

  bool _salvando = false;

  bool get _editando => widget.rebanhoParaEditar != null;

  @override
  void initState() {
    super.initState();

    final rebanho = widget.rebanhoParaEditar;

    if (rebanho != null) {
      _nomeController.text = rebanho.nome;
      _descricaoController.text = rebanho.descricao ?? '';
      _finalidadeController.text = rebanho.finalidade ?? '';
      _localizacaoController.text = rebanho.localizacao ?? '';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _finalidadeController.dispose();
    _localizacaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      Map<String, dynamic> dados;

      if (_editando) {
        dados = await _rebanhoService.atualizarRebanho(
          id: widget.rebanhoParaEditar!.id,
          nome: _nomeController.text,
          descricao: _descricaoController.text,
          finalidade: _finalidadeController.text,
          localizacao: _localizacaoController.text,
          ativo: widget.rebanhoParaEditar!.ativo,
        );
      } else {
        dados = await _rebanhoService.criarRebanho(
          nome: _nomeController.text,
          descricao: _descricaoController.text,
          finalidade: _finalidadeController.text,
          localizacao: _localizacaoController.text,
        );
      }

      final rebanho = Rebanho.fromMap(dados);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(rebanho);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mensagemErro(error))));
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  String _mensagemErro(Object error) {
    final mensagem = error.toString();

    if (mensagem.startsWith('Exception: ')) {
      return mensagem.substring('Exception: '.length);
    }

    return 'Não foi possível salvar o lote.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar lote' : 'Novo lote'),
        actions: const [
          ContextualHelpButton(
            title: 'Organizar animais em lotes',
            introduction: 'Use lotes para separar grupos de animais, como matrizes, cordeiros ou animais em engorda.',
            topics: [
              HelpTopic(
                title: 'Nome e descrição',
                description: 'Escolha um nome fácil de reconhecer e use a descrição para anotar a finalidade do lote.',
              ),
              HelpTopic(
                title: 'Mover animais',
                description: 'Após salvar, abra um animal para transferi-lo entre lotes quando necessário.',
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.pets_rounded,
                      color: AppTheme.primaryColor,
                      size: 30,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Crie um grupo para organizar os animais da fazenda.',
                        style: TextStyle(
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomeController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome do lote',
                  hintText: 'Ex.: Lote 01',
                  prefixIcon: Icon(Icons.pets_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome do lote.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex.: Grupo separado para o pasto de baixo',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _finalidadeController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Finalidade',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _localizacaoController,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Localização',
                  hintText: 'Ex.: Pasto de baixo',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                onFieldSubmitted: (_) {
                  _salvar();
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_salvando ? 'Salvando...' : 'Salvar lote'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
