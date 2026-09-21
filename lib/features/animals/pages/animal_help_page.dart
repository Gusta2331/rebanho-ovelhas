import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AnimalHelpPage extends StatelessWidget {
  const AnimalHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuda sobre animais'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _intro(context),
          const SizedBox(height: 16),
          _section(
            context,
            'Cadastro do animal',
            Icons.pets_outlined,
            [
              _item(
                'Brinco',
                'É o número de identificação usado para reconhecer o animal no rebanho. Cada brinco é único na fazenda e não deve ser reutilizado.',
              ),
              _item(
                'Nome',
                'É opcional e serve para facilitar a identificação do animal além do número do brinco.',
              ),
              _item(
                'Sexo',
                'Indica se o animal é fêmea ou macho. Essa informação também é usada em recursos como reprodução.',
              ),
              _item(
                'Raça',
                'Identifica a raça do animal. As raças podem ser cadastradas na biblioteca de raças.',
              ),
              _item(
                'Data de nascimento',
                'Ajuda o sistema a calcular a idade e acompanhar o desenvolvimento do animal.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            context,
            'Status do animal',
            Icons.flag_outlined,
            [
              _item(
                'Ativo',
                'Animal que atualmente faz parte do rebanho.',
              ),
              _item(
                'Vendido',
                'Animal que saiu da fazenda por venda. O cadastro permanece no histórico.',
              ),
              _item(
                'Morto',
                'Animal que morreu. O cadastro permanece no histórico para manter os registros da fazenda.',
              ),
              _item(
                'Descartado',
                'Animal que deixou de fazer parte do rebanho por descarte. O histórico também é preservado.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            context,
            'Rebanho e histórico',
            Icons.groups_outlined,
            [
              _item(
                'Rebanho atual',
                'Indica em qual grupo de animais o animal está atualmente. Um animal pertence a um rebanho por vez.',
              ),
              _item(
                'Transferência',
                'Quando o animal muda de rebanho, a movimentação pode ser registrada para preservar seu histórico.',
              ),
              _item(
                'Filiação',
                'Mostra a mãe e o pai cadastrados para o animal, quando essas informações estiverem disponíveis.',
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
                'Aqui você encontra uma explicação dos principais campos e conceitos usados no cadastro e acompanhamento dos animais.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
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
                Icon(
                  icone,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            descricao,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
            ),
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
          Icon(
            Icons.lightbulb_outline_rounded,
            color: AppTheme.primaryColor,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dica: animais vendidos, mortos ou descartados não devem ser apagados. Manter esses registros permite consultar o histórico da fazenda.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
