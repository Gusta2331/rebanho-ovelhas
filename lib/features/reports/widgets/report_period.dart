import 'package:flutter/material.dart';

enum ReportPeriodType { all, week, month, year, custom }

class ReportPeriod {
  final ReportPeriodType type;
  final DateTime? start;
  final DateTime? end;

  const ReportPeriod._(this.type, this.start, this.end);

  const ReportPeriod.all() : this._(ReportPeriodType.all, null, null);

  const ReportPeriod.custom(DateTime start, DateTime end)
      : this._(ReportPeriodType.custom, start, end);

  ReportPeriod copyWith({
    ReportPeriodType? type,
    DateTime? start,
    DateTime? end,
  }) {
    return ReportPeriod._(type ?? this.type, start ?? this.start, end ?? this.end);
  }

  (DateTime, DateTime)? range([DateTime? now]) {
    final today = now ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    switch (type) {
      case ReportPeriodType.all:
        return null;
      case ReportPeriodType.week:
        return (day.subtract(const Duration(days: 6)), day);
      case ReportPeriodType.month:
        return (DateTime(day.year, day.month - 1, day.day), day);
      case ReportPeriodType.year:
        return (DateTime(day.year - 1, day.month, day.day), day);
      case ReportPeriodType.custom:
        if (start == null || end == null) return null;
        return (
          DateTime(start!.year, start!.month, start!.day),
          DateTime(end!.year, end!.month, end!.day),
        );
    }
  }

  String get label {
    switch (type) {
      case ReportPeriodType.all:
        return 'Todo o período';
      case ReportPeriodType.week:
        return 'Última semana';
      case ReportPeriodType.month:
        return 'Último mês';
      case ReportPeriodType.year:
        return 'Último ano';
      case ReportPeriodType.custom:
        if (start != null && end != null) {
          return formatDate(start!) + ' a ' + formatDate(end!);
        }
        return 'Período personalizado';
    }
  }

  static String formatDate(DateTime value) =>
      value.day.toString().padLeft(2, '0') + '/' +
      value.month.toString().padLeft(2, '0') + '/' +
      value.year.toString();
}

class ReportPeriodCard extends StatelessWidget {
  final ReportPeriod value;
  final ValueChanged<ReportPeriod> onChanged;

  const ReportPeriodCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _choose(BuildContext context) async {
    var type = value.type;
    var start = value.start;
    var end = value.end;

    final result = await showDialog<ReportPeriod>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Período do relatório'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _radio(
                'Todo o período',
                ReportPeriodType.all,
                type,
                (v) => setState(() => type = v),
              ),
              _radio(
                'Última semana',
                ReportPeriodType.week,
                type,
                (v) => setState(() => type = v),
              ),
              _radio(
                'Último mês',
                ReportPeriodType.month,
                type,
                (v) => setState(() => type = v),
              ),
              _radio(
                'Último ano',
                ReportPeriodType.year,
                type,
                (v) => setState(() => type = v),
              ),
              _radio(
                'Período personalizado',
                ReportPeriodType.custom,
                type,
                (v) => setState(() => type = v),
              ),
              if (type == ReportPeriodType.custom)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(
                    start == null || end == null
                        ? 'Escolher datas'
                        : ReportPeriod.formatDate(start!) + ' a ' +
                            ReportPeriod.formatDate(end!),
                  ),
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: dialogContext,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: start != null && end != null
                          ? DateTimeRange(start: start!, end: end!)
                          : null,
                    );
                    if (picked != null) {
                      setState(() {
                        start = picked.start;
                        end = picked.end;
                      });
                    }
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: type == ReportPeriodType.custom &&
                      (start == null || end == null)
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        ReportPeriod._(type, start, end),
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
    ReportPeriodType option,
    ReportPeriodType selected,
    ValueChanged<ReportPeriodType> onSelected,
  ) {
    return RadioListTile<ReportPeriodType>(
      value: option,
      groupValue: selected,
      title: Text(label),
      contentPadding: EdgeInsets.zero,
      onChanged: (v) {
        if (v != null) onSelected(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _choose(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.date_range_rounded, color: Color(0xFF367C2B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Período do relatório',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value.label,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
