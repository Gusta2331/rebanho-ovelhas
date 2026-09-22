import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../farmacia/pages/farmacia_page.dart';
import '../financeiro/pages/financeiro_page.dart';
import '../manejo/pages/manejo_agenda_page.dart';
import '../reproduction/pages/reproductions_page.dart';

class MaisPage extends StatelessWidget {
  const MaisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final itens = [
      _Item(
        icon: Icons.event_note_outlined,
        titulo: 'Agenda de manejo',
        descricao: 'Manejos programados do lote',
        onTap: () => _abrir(context, const ManejoAgendaPage()),
      ),
      _Item(
        icon: Icons.favorite_outline_rounded,
        titulo: 'Reprodução',
        descricao: 'Montas, coberturas e nascimentos',
        onTap: () => _abrir(context, const ReproductionsPage()),
      ),
      _Item(
        icon: Icons.medical_services_outlined,
        titulo: 'Farmácia',
        descricao: 'Estoque e uso de produtos',
        onTap: () => _abrir(context, const FarmaciaPage()),
      ),
      _Item(
        icon: Icons.attach_money_rounded,
        titulo: 'Despesas e lucro',
        descricao: 'Receitas, despesas e saldo do lote',
        onTap: () => _abrir(context, const FinanceiroPage()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: itens.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final item = itens[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.10),
                foregroundColor: AppTheme.primaryColor,
                child: Icon(item.icon),
              ),
              title: Text(item.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.descricao),
              trailing: const Icon(Icons.chevron_right),
              onTap: item.onTap,
            ),
          );
        },
      ),
    );
  }

  void _abrir(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _Item {
  final IconData icon;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });
}
