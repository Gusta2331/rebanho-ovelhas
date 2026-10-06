import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_asset_icon.dart';
import '../../../core/widgets/contextual_help.dart';
import '../models/report_type.dart';
import 'rebanho_report_page.dart';
import 'reproducao_report_page.dart';
import 'manejo_report_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportType? _selectedType;

  @override
  Widget build(BuildContext context) {
    if (_selectedType == ReportType.reproducao) {
      return ReproducaoReportPage(
        onBack: () => setState(() => _selectedType = null),
      );
    }

    if (_selectedType == ReportType.rebanho) {
      return RebanhoReportPage(
        onBack: () => setState(() => _selectedType = null),
      );
    }

    if (_selectedType == ReportType.manejo) {
      return ManejoReportPage(
        onBack: () => setState(() => _selectedType = null),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(
              assetPath: 'assets/images/icon_relatorios.png',
              size: 26,
            ),
            SizedBox(width: 8),
            Text('Relatórios'),
          ],
        ),
        actions: const [
          ContextualHelpButton(
            title: 'Relatórios',
            introduction:
                'Escolha o tipo de relatório que deseja consultar ou gerar.',
            topics: [
              HelpTopic(
                title: 'Formatos',
                description:
                    'Cada relatório poderá ser gerado em PDF ou Excel, conforme a opção escolhida.',
              ),
              HelpTopic(
                title: 'Categorias',
                description:
                    'Cada categoria reúne informações específicas da Fazenda Baixinha.',
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _ReportsHeader(),
          const SizedBox(height: 20),
          ...ReportType.values.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(
                type: type,
                onTap: () {
                  if (type == ReportType.manejo) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ManejoReportPage(
                          onBack: () => Navigator.of(context).pop(),
                        ),
                      ),
                    );
                    return;
                  }

                  _openType(type);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openType(ReportType type) {
    switch (type) {
      case ReportType.rebanho:
        setState(() => _selectedType = ReportType.rebanho);
        return;
      case ReportType.reproducao:
        setState(() => _selectedType = ReportType.reproducao);
        return;
      case ReportType.manejo:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ManejoReportPage(
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'O relatório de ' +
                  type.title.toLowerCase() +
                  ' será disponibilizado na próxima etapa.',
            ),
          ),
        );
    }
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Central de relatórios',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Escolha uma categoria, aplique os filtros e gere o arquivo no formato que precisar.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportType type;
  final VoidCallback onTap;

  const _ReportCard({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: AppAssetIcon(
                  assetPath: type.iconAsset,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
