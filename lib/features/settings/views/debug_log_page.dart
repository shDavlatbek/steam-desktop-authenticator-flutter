import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/debug_logger.dart';
import '../../../shared/theme/colors.dart';

/// Displays captured debug log entries in a scrollable list.
class DebugLogPage extends StatelessWidget {
  const DebugLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all logs',
            onPressed: () => _copyAll(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () {
              DebugLogger().clear();
              // Force rebuild
              (context as Element).markNeedsBuild();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: DebugLogger(),
        builder: (context, _) {
          final entries = DebugLogger().entries;

          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'No log entries yet.\nPerform actions to see logs here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SteamColors.textSecondary),
              ),
            );
          }

          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              // Show newest first
              final entry = entries[entries.length - 1 - index];
              return _LogEntryTile(entry: entry);
            },
          );
        },
      ),
    );
  }

  void _copyAll(BuildContext context) {
    final text = DebugLogger().entries.map((e) => e.toString()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final DebugLogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      'ERROR' => SteamColors.error,
      'HTTP' => SteamColors.steamBlue,
      _ => SteamColors.textSecondary,
    };

    final ts =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: entry.toString()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log entry copied')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.level,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.source,
                    style: const TextStyle(
                        color: SteamColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    ts,
                    style: const TextStyle(
                        color: SteamColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.message,
                style: const TextStyle(
                    color: SteamColors.textPrimary, fontSize: 12),
              ),
              if (entry.detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  entry.detail!,
                  style: const TextStyle(
                      color: SteamColors.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace'),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
