import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class RebanhoHelpPage extends StatelessWidget {
  const RebanhoHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuda sobre lotes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _intro(context),
          const SizedBox(height: 16),
          _section(context, 'O que é um lote?', Icons.groups_outlined, [
            _item(
              'Lote',
              'É um grupo de animais organizado dentro da fazenda. Uma fazenda pode ter vários lotes.',
            ),
            _item(
              'Quantidade de animais',
              'Mostra quantos animais ativos estão atualmente naquele lote.',
            ),
            _item(
              'Nome',
              'É a identificação usada para diferenciar um lote dos outros, como Lote 01 ou Lote 02.',
            ),
          ]),
          const SizedBox(height: 16),
          _section(
            context,
            'Informações do lote',
            Icons.info_outline_rounded,
            [
              _item(
                'Descrição',
                'Pode ser usada para registrar uma informação complementar sobre o grupo.',
              ),
              _item(
                'Finalidade',
                'Serve para informar o objetivo ou característica daquele grupo de animais.',
              ),
              _item(
                'Localização',
                'Indica onde o lote está mantido na propriedade, quando essa informação for útil.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(context, 'Ativo e inativo', Icons.toggle_on_outlined, [
            _item(
              'Lote ativo',
              'Pode ser utilizado normalmente e pode receber animais.',
            ),
            _item(
              'Lote inativo',
              'Deixa de ser usado como lote ativo, mas seus registros são preservados.',
            ),
          ]),
          const SizedBox(height: 16),
          _section(
            context,
            'Lote selecionado',
            Icons.check_circle_outline_rounded,
            [
              _item(
                'Seleção atual',
                'O lote selecionado define quais animais aparecem em telas que trabalham com um lote específico.',
              ),
              _item(
                'Cadastro de animais',
                'Ao cadastrar um novo animal, ele pertence automaticamente ao lote selecionado.',
              ),
              _item(
                'Troca de lote',
                'Um animal pode ser transferido para outro lote. A movimentação pode ser registrada para preservar o histórico.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _tip(context),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.help_outline_rounded,
              color: AppTheme.primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Os lotes servem para organizar os animais da fazenda em grupos. Eles não representam categorias como “matrizes” ou “cordeiros”.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String titulo,
    IconData icone,
    List<Widget> itens,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...itens,
          ],
        ),
      ),
    );
  }

  Widget _item(String titulo, String descricao) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            descricao,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _tip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primaryColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dica: um animal pertence a um lote por vez. Quando ele mudar de grupo, use a transferência para manter o histórico da movimentação.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
