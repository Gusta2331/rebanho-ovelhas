import 'package:flutter/material.dart';

enum ReportAgeType {
  all,
  months0to3,
  months3to6,
  months6to12,
  years1to2,
  years2to4,
  over4,
  custom,
}

class ReportAge {
  final ReportAgeType type;
  final int? minMonths;
  final int? maxMonths;

  const ReportAge._(this.type, this.minMonths, this.maxMonths);

  const ReportAge.all() : this._(ReportAgeType.all, null, null);

  const ReportAge.custom(int minMonths, int maxMonths)
      : this._(ReportAgeType.custom, minMonths, maxMonths);

  String get label {
    switch (type) {
      case ReportAgeType.all:
        return 'Todas as idades';
      case ReportAgeType.months0to3:
        return '0 a 3 meses';
      case ReportAgeType.months3to6:
        return '3 a 6 meses';
      case ReportAgeType.months6to12:
        return '6 meses a 1 ano';
      case ReportAgeType.years1to2:
        return '1 a 2 anos';
      case ReportAgeType.years2to4:
        return '2 a 4 anos';
      case ReportAgeType.over4:
        return 'Mais de 4 anos';
      case ReportAgeType.custom:
        return minMonths == null || maxMonths == null
            ? 'Idade personalizada'
            : _formatRange(minMonths!, maxMonths!);
    }
  }

  bool matches(DateTime? birth, [DateTime? now]) {
    if (type == ReportAgeType.all) return true;
    if (birth == null) return false;

    final today = now ?? DateTime.now();
    var months = (today.year - birth.year) * 12 + today.month - birth.month;
    if (today.day < birth.day) months--;
    if (months < 0) return false;

    switch (type) {
      case ReportAgeType.all:
        return true;
      case ReportAgeType.months0to3:
        return months >= 0 && months < 3;
      case ReportAgeType.months3to6:
        return months >= 3 && months < 6;
      case ReportAgeType.months6to12:
        return months >= 6 && months < 12;
      case ReportAgeType.years1to2:
        return months >= 12 && months < 24;
      case ReportAgeType.years2to4:
        return months >= 24 && months < 48;
      case ReportAgeType.over4:
        return months >= 48;
      case ReportAgeType.custom:
        return minMonths != null &&
            maxMonths != null &&
            months >= minMonths! &&
            months <= maxMonths!;
    }
  }

  static String _formatRange(int min, int max) {
    return _formatMonths(min) + ' a ' + _formatMonths(max);
  }

  static String _formatMonths(int months) {
    if (months < 12) return months.toString() + ' meses';
    final years = months ~/ 12;
    final remaining = months % 12;
    if (remaining == 0) return years.toString() + (years == 1 ? ' ano' : ' anos');
    return years.toString() +
        (years == 1 ? ' ano e ' : ' anos e ') +
        remaining.toString() +
        ' meses';
  }
}

class ReportAgeCard extends StatelessWidget {
  final ReportAge value;
  final ValueChanged<ReportAge> onChanged;

  const ReportAgeCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _choose(BuildContext context) async {
    var type = value.type;
    var minMonths = value.minMonths;
    var maxMonths = value.maxMonths;

    final result = await showDialog<ReportAge>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Idade dos animais'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _radio('Todas as idades', ReportAgeType.all, type,
                    (v) => setState(() => type = v)),
                _radio('0 a 3 meses', ReportAgeType.months0to3, type,
                    (v) => setState(() => type = v)),
                _radio('3 a 6 meses', ReportAgeType.months3to6, type,
                    (v) => setState(() => type = v)),
                _radio('6 meses a 1 ano', ReportAgeType.months6to12, type,
                    (v) => setState(() => type = v)),
                _radio('1 a 2 anos', ReportAgeType.years1to2, type,
                    (v) => setState(() => type = v)),
                _radio('2 a 4 anos', ReportAgeType.years2to4, type,
                    (v) => setState(() => type = v)),
                _radio('Mais de 4 anos', ReportAgeType.over4, type,
                    (v) => setState(() => type = v)),
                _radio('Idade personalizada', ReportAgeType.custom, type,
                    (v) => setState(() => type = v)),
                if (type == ReportAgeType.custom)
                  _customFields(
                    context,
                    minMonths: minMonths,
                    maxMonths: maxMonths,
                    onChanged: (min, max) {
                      setState(() {
                        minMonths = min;
                        maxMonths = max;
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: type == ReportAgeType.custom &&
                      (minMonths == null ||
                          maxMonths == null ||
                          minMonths! < 0 ||
                          maxMonths! <= minMonths!)
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        ReportAge._(type, minMonths, maxMonths),
                      ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );

    if (result != null) onChanged(result);
  }

  Widget _radio(
    String label,
    ReportAgeType option,
    ReportAgeType selected,
    ValueChanged<ReportAgeType> onSelected,
  ) {
    return RadioListTile<ReportAgeType>(
      value: option,
      groupValue: selected,
      title: Text(label),
      contentPadding: EdgeInsets.zero,
      onChanged: (v) {
        if (v != null) onSelected(v);
      },
    );
  }

  Widget _customFields(
    BuildContext context, {
    required int? minMonths,
    required int? maxMonths,
    required void Function(int?, int?) onChanged,
  }) {
    final minController = TextEditingController(
      text: minMonths?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: maxMonths?.toString() ?? '',
    );

    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Informe a idade mínima e máxima em meses.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mínimo',
                  suffixText: 'meses',
                ),
                onChanged: (value) {
                  onChanged(int.tryParse(value), maxMonths);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Máximo',
                  suffixText: 'meses',
                ),
                onChanged: (value) {
                  onChanged(minMonths, int.tryParse(value));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
