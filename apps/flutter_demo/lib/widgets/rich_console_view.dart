import 'dart:async';

import 'package:flutter/material.dart';
import 'package:merkle_kv_core/src/mqtt/connection_logger.dart';
import 'package:merkle_kv_core/src/mqtt/log_entry.dart';

class RichConsoleView extends StatefulWidget {
  final StreamConnectionLogger logger;
  final Set<String>? levels; // e.g., {'DEBUG','INFO','WARN','ERROR'}
  final String? tag;
  final String? contains;

  const RichConsoleView({
    super.key,
    required this.logger,
    this.levels,
    this.tag,
    this.contains,
  });

  @override
  State<RichConsoleView> createState() => _RichConsoleViewState();
}

class _RichConsoleViewState extends State<RichConsoleView> {
  late StreamSubscription<ConnectionLogEntry> _sub;
  final List<ConnectionLogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    // Seed with buffer snapshot for instant UI
    _entries.addAll(widget.logger.bufferSnapshot);
    _sub = widget.logger
        .filtered(levels: widget.levels, tag: widget.tag, contains: widget.contains)
        .listen((e) {
      setState(() => _entries.add(e));
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'DEBUG':
        return Colors.cyanAccent;
      case 'INFO':
        return Colors.greenAccent;
      case 'WARN':
        return Colors.yellowAccent;
      case 'ERROR':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  FontWeight _levelWeight(String level) {
    switch (level) {
      case 'INFO':
      case 'WARN':
      case 'ERROR':
        return FontWeight.bold;
      default:
        return FontWeight.normal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _entries.clear();
                  widget.logger.clear();
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
            const SizedBox(width: 12),
            Text('Level filter: ${widget.levels?.join(', ') ?? 'ALL'}'),
            const SizedBox(width: 12),
            Text('Tag: ${widget.tag ?? 'ANY'}'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final e = _entries[index];
                final ts = e.timestamp.toIso8601String();
                final tag = e.tag != null ? ' [${e.tag}]' : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$ts ',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        TextSpan(
                          text: '${e.level} ',
                          style: TextStyle(
                            color: _levelColor(e.level),
                            fontWeight: _levelWeight(e.level),
                          ),
                        ),
                        TextSpan(
                          text: tag,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        const TextSpan(text: '  ', style: TextStyle(color: Colors.white70)),
                        TextSpan(
                          text: e.message,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (e.error != null)
                          TextSpan(
                            text: '\n↳ ${e.error}',
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        if (e.stackTrace != null)
                          TextSpan(
                            text: '\n↳ ${e.stackTrace}',
                            style: const TextStyle(color: Colors.purpleAccent, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
