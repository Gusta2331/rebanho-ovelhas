import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ReproductionHelpPage extends StatelessWidget {
  const ReproductionHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuda sobre reprodução')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _intro(context),
          const SizedBox(height: 16),
          _section(context, 'Como funciona', Icons.sync_alt_rounded, [
            _item(
              'Mãe',
              'É a ovelha que está sendo acompanhada nessa reprodução.',
            ),
            _item(
              'Pai',
              'É o carneiro identificado como pai. Pode ser informado depois, quando ainda não estiver definido.',
            ),
            _item(
              'Monta / cobertura',
              'É o registro do acasalamento entre a ovelha e um carneiro. Uma reprodução pode ter mais de uma cobertura.',
            ),
            _item(
              'Previsão de parto',
              'É a data estimada para o parto. Serve como referência para acompanhar a gestação.',
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Status da reprodução', Icons.flag_outlined, [
            _item(
              'Planejada',
              'A reprodução foi cadastrada, mas ainda não foi confirmada como coberta.',
            ),
            _item('Coberta', 'Já houve cobertura ou monta registrada.'),
            _item('Prenhe', 'A gestação foi confirmada.'),
            _item(
              'Não prenhe',
              'A gestação não foi confirmada ou foi constatado que a ovelha não está prenhe.',
            ),
            _item(
              'Abortou',
              'A gestação foi interrompida antes do nascimento.',
            ),
            _item(
              'Parto realizado',
              'O parto aconteceu e os nascimentos podem ser registrados.',
            ),
            _item(
              'Encerrada',
              'O acompanhamento dessa reprodução foi finalizado.',
            ),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Nascimentos', Icons.child_friendly_outlined, [
            _item(
              'Nascimento',
              'Registra um cordeiro relacionado à reprodução. O animal precisa existir no cadastro para ser vinculado ao nascimento.',
            ),
          ]),
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
                'Aqui você acompanha o ciclo reprodutivo das ovelhas, desde a cobertura até o parto e os nascimentos.',
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
              'Dica: você pode deixar o pai em branco quando ainda não souber qual carneiro foi responsável pela cobertura. Ele poderá ser informado depois.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
