import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HelpTopic {
  const HelpTopic({
    required this.title,
    required this.description,
    this.icon = Icons.info_outline_rounded,
  });

  final String title;
  final String description;
  final IconData icon;
}

class ContextualHelpButton extends StatelessWidget {
  const ContextualHelpButton({
    super.key,
    required this.title,
    required this.introduction,
    required this.topics,
  });

  final String title;
  final String introduction;
  final List<HelpTopic> topics;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Ajuda',
    icon: const Icon(Icons.help_outline_rounded),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ContextualHelpPage(
          title: title,
          introduction: introduction,
          topics: topics,
        ),
      ),
    ),
  );
}

class _ContextualHelpPage extends StatelessWidget {
  const _ContextualHelpPage({
    required this.title,
    required this.introduction,
    required this.topics,
  });

  final String title;
  final String introduction;
  final List<HelpTopic> topics;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Ajuda: $title')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    introduction,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...topics.map(
          (topic) => Card(
            child: ListTile(
              leading: Icon(topic.icon, color: AppTheme.primaryColor),
              title: Text(
                topic.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  topic.description,
                  style: const TextStyle(height: 1.4),
                ),
              ),
              isThreeLine: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}
