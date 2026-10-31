import 'package:flutter/material.dart';

import 'app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({super.key, required this.update});

  final AppUpdateInfo update;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _baixando = false;
  double? _progresso;
  String? _erro;

  Future<void> _atualizar() async {
    setState(() {
      _baixando = true;
      _progresso = null;
      _erro = null;
    });

    try {
      final apkPath = await AppUpdateService.instance.baixarAtualizacao(
        widget.update,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progresso = total > 0 ? received / total : null;
          });
        },
      );

      if (!mounted) return;
      await AppUpdateService.instance.instalarAtualizacao(apkPath);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _erro = error.toString().replaceFirst('Exception: ', '');
        _baixando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = widget.update.releaseNotes;

    return PopScope(
      canPop: !_baixando,
      child: AlertDialog(
        title: const Text('Atualização disponível'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uma nova versão do OviGestão (${widget.update.version}) está disponível.',
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Novidades', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(child: Text(notes)),
                ),
              ],
              if (_baixando) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(value: _progresso),
                const SizedBox(height: 8),
                Text(
                  _progresso == null
                      ? 'Baixando atualização...'
                      : 'Baixando ${(100 * _progresso!).toStringAsFixed(0)}%',
                ),
              ],
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 8),
              const Text(
                'Depois do download, o Android abrirá o instalador. Confirme a instalação para continuar usando o aplicativo atualizado.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _baixando ? null : () => Navigator.of(context).pop(),
            child: const Text('Depois'),
          ),
          FilledButton.icon(
            onPressed: _baixando ? null : _atualizar,
            icon: const Icon(Icons.download),
            label: Text(_erro == null ? 'Atualizar' : 'Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
