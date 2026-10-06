import 'package:flutter/material.dart';

import '../../../core/widgets/app_asset_icon.dart';

class ManejoReportPage extends StatelessWidget {
  final VoidCallback onBack;

  const ManejoReportPage({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetIcon(
              assetPath: 'assets/images/icon_manejo.png',
              size: 26,
            ),
            SizedBox(width: 8),
            Text('Relatório de manejo'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  AppAssetIcon(
                    assetPath: 'assets/images/icon_manejo.png',
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Relatório de manejo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A tela do relatório de manejo foi aberta corretamente.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
