import 'package:flutter/material.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';

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
  final List<ConnectionLogEntry> _entries = <ConnectionLogEntry>[];

  @override
  void initState() {
    super.initState();
    // Seed with filtered buffer snapshot for instant UI
    _entries.addAll(
      widget.logger.bufferSnapshot.where(_matches),
    );
  }

  @override
  void dispose() {
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
    final logStream = widget.logger.filtered(
      levels: widget.levels,
      tag: widget.tag,
      contains: widget.contains,
    );

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
            child: StreamBuilder<ConnectionLogEntry>(
              stream: logStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _entries.add(snapshot.data!);
                }
                return ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final e = _entries[index];
                    return _buildEntry(e);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  bool _matches(ConnectionLogEntry e) {
    // Level filter
    if (widget.levels != null && widget.levels!.isNotEmpty) {
      if (!widget.levels!.contains(e.level)) return false;
    }
    // Tag filter
    if (widget.tag != null && widget.tag!.isNotEmpty) {
      if (e.tag != widget.tag) return false;
    }
    // Contains filter
    if (widget.contains != null && widget.contains!.isNotEmpty) {
      final hay = '${e.message} ${e.error ?? ''} ${e.stackTrace ?? ''}'.toLowerCase();
      if (!hay.contains(widget.contains!.toLowerCase())) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant RichConsoleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final levelsChanged = oldWidget.levels != widget.levels;
    final tagChanged = oldWidget.tag != widget.tag;
    final containsChanged = oldWidget.contains != widget.contains;
    if (levelsChanged || tagChanged || containsChanged) {
      setState(() {
        _entries
          ..clear()
          ..addAll(widget.logger.bufferSnapshot.where(_matches));
      });
    }
  }

  Widget _buildEntry(ConnectionLogEntry e) {
    final ts = e.timestamp.toIso8601String();
    final tagText = e.tag != null ? ' [${e.tag}]' : '';

    // ERROR: bgRed + white/bold, show error/stack
    if (e.level == 'ERROR') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(6),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$ts ERROR$tagText  ${e.message}'),
              if (e.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text('↳ ${e.error}', style: const TextStyle(color: Colors.white)),
                ),
              if (e.stackTrace != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text('↳ ${e.stackTrace}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
                ),
            ],
          ),
        ),
      );
    }

    // Non-error entries: styled inline
    final levelColor = _levelColor(e.level);
    final levelWeight = _levelWeight(e.level);

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
              style: TextStyle(color: levelColor, fontWeight: levelWeight),
            ),
            TextSpan(
              text: tagText,
              style: const TextStyle(color: Colors.white54),
            ),
            const TextSpan(text: '  ', style: TextStyle(color: Colors.white70)),
            TextSpan(
              text: e.message,
              style: const TextStyle(color: Colors.white70),
            ),
            if (e.level == 'WARN' && e.error != null)
              const TextSpan(text: '  '),
            if (e.level == 'WARN' && e.error != null)
              TextSpan(
                text: '↳ ${e.error}',
                style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
