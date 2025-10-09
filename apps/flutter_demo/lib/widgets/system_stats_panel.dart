import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class SystemStats {
  final int? memTotalBytes;
  final int? memAvailableBytes;
  final double? cpuPercent; // 0-100
  final int? storageUsedBytes; // optional, for a provided directory
  final int? storageTotalBytes; // not available without platform APIs
  final int? rxBytesTotal;
  final int? txBytesTotal;
  final double? rxKbps; // instantaneous, since last sample
  final double? txKbps; // instantaneous, since last sample

  const SystemStats({
    this.memTotalBytes,
    this.memAvailableBytes,
    this.cpuPercent,
    this.storageUsedBytes,
    this.storageTotalBytes,
    this.rxBytesTotal,
    this.txBytesTotal,
    this.rxKbps,
    this.txKbps,
  });

  double? get memUsagePercent {
    if (memTotalBytes == null || memAvailableBytes == null) return null;
    final used = memTotalBytes! - memAvailableBytes!;
    if (memTotalBytes == 0) return 0;
    return used * 100.0 / memTotalBytes!;
  }
}

/// Reads best-effort system stats from /proc on Linux/Android. Returns nulls
/// for unsupported platforms or when files are missing.
class ProcStatsReader {
  Future<Map<String, int?>> readMemInfo() async {
    try {
      final lines = await File('/proc/meminfo').readAsLines();
      int? total;
      int? avail;
      for (final l in lines) {
        if (l.startsWith('MemTotal:')) {
          total = _parseKbLine(l);
        } else if (l.startsWith('MemAvailable:')) {
          avail = _parseKbLine(l);
        }
      }
      return {
        'total': total != null ? total * 1024 : null,
        'available': avail != null ? avail * 1024 : null,
      };
    } catch (_) {
      return {'total': null, 'available': null};
    }
  }

  int? _parseKbLine(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return int.tryParse(parts[1]);
    }
    return null;
  }

  Future<Map<String, int?>> readCpuJiffies() async {
    try {
      final first = await File('/proc/stat').readAsLines();
      // first line starts with 'cpu '
      for (final l in first) {
        if (l.startsWith('cpu ')) {
          final parts = l.split(RegExp(r'\s+'));
          // cpu user nice system idle iowait irq softirq steal guest guest_nice
          // indexes: [0]=cpu, [1]=user, [2]=nice, [3]=system, [4]=idle, [5]=iowait, ...
          if (parts.length >= 8) {
            final user = int.tryParse(parts[1]) ?? 0;
            final nice = int.tryParse(parts[2]) ?? 0;
            final system = int.tryParse(parts[3]) ?? 0;
            final idle = int.tryParse(parts[4]) ?? 0;
            final iowait = int.tryParse(parts[5]) ?? 0;
            final irq = int.tryParse(parts[6]) ?? 0;
            final softirq = int.tryParse(parts[7]) ?? 0;
            final steal = parts.length > 8 ? (int.tryParse(parts[8]) ?? 0) : 0;
            final total = user + nice + system + idle + iowait + irq + softirq + steal;
            final idleAll = idle + iowait;
            return {'total': total, 'idle': idleAll};
          }
        }
      }
    } catch (_) {}
    return {'total': null, 'idle': null};
  }

  Future<Map<String, int?>> readNetBytesTotals({bool includeLoopback = false}) async {
    try {
      final lines = await File('/proc/net/dev').readAsLines();
      int rx = 0;
      int tx = 0;
      for (final l in lines.skip(2)) {
        final parts = l.split(':');
        if (parts.length != 2) continue;
        final iface = parts[0].trim();
        if (!includeLoopback && iface == 'lo') continue;
        final fields = parts[1].trim().split(RegExp(r'\s+'));
        if (fields.length >= 16) {
          final rxBytes = int.tryParse(fields[0]) ?? 0; // first field = rx bytes
          final txBytes = int.tryParse(fields[8]) ?? 0; // 9th field = tx bytes
          rx += rxBytes;
          tx += txBytes;
        }
      }
      return {'rx': rx, 'tx': tx};
    } catch (_) {
      return {'rx': null, 'tx': null};
    }
  }

  Future<int?> computeDirectorySizeBytes(Directory dir, {int maxEntries = 5000}) async {
    try {
      int total = 0;
      int count = 0;
      final lister = dir.list(recursive: true, followLinks: false);
      await for (final entity in lister) {
        if (count++ > maxEntries) break; // avoid heavy scans
        if (entity is File) {
          final stat = await entity.stat();
          total += stat.size;
        }
      }
      return total;
    } catch (_) {
      return null;
    }
  }
}

class SystemStatsPanel extends StatefulWidget {
  final Duration refreshInterval;
  final Directory? storageDir; // optional directory to compute size
  final bool includeLoopback;
  final bool autoRefresh; // allow test harnesses to disable timers

  const SystemStatsPanel({
    super.key,
    this.refreshInterval = const Duration(seconds: 1),
    this.storageDir,
    this.includeLoopback = false,
    this.autoRefresh = true,
  });

  @override
  State<SystemStatsPanel> createState() => _SystemStatsPanelState();
}

class _SystemStatsPanelState extends State<SystemStatsPanel> {
  final _reader = ProcStatsReader();
  Timer? _timer;
  SystemStats _stats = const SystemStats();

  int? _prevCpuTotal;
  int? _prevCpuIdle;
  int? _prevRx;
  int? _prevTx;
  DateTime? _prevNetSample;

  @override
  void initState() {
    super.initState();
    _tick();
  final bool isUnderTest = const bool.fromEnvironment('FLUTTER_TEST') ||
    WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (widget.autoRefresh && !isUnderTest) {
      _timer = Timer.periodic(widget.refreshInterval, (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    // If the widget is already disposed or unmounted, do nothing.
    if (!mounted) return;
    if (!(Platform.isLinux || Platform.isAndroid)) {
      if (!mounted) return;
      setState(() => _stats = const SystemStats());
      return;
    }

    final mem = await _reader.readMemInfo();
    final cpu = await _reader.readCpuJiffies();
    final net = await _reader.readNetBytesTotals(includeLoopback: widget.includeLoopback);

    double? cpuPct;
    if (cpu['total'] != null && cpu['idle'] != null && _prevCpuTotal != null && _prevCpuIdle != null) {
      final dTotal = (cpu['total']! - _prevCpuTotal!).toDouble();
      final dIdle = (cpu['idle']! - _prevCpuIdle!).toDouble();
      if (dTotal > 0) {
        cpuPct = (1.0 - (dIdle / dTotal)) * 100.0;
        if (cpuPct < 0) cpuPct = 0;
        if (cpuPct > 100) cpuPct = 100;
      }
    }
    _prevCpuTotal = cpu['total'];
    _prevCpuIdle = cpu['idle'];

    double? rxKbps;
    double? txKbps;
    final now = DateTime.now();
    if (net['rx'] != null && net['tx'] != null && _prevRx != null && _prevTx != null && _prevNetSample != null) {
      final dt = now.difference(_prevNetSample!).inMilliseconds / 1000.0;
      if (dt > 0) {
        rxKbps = ((net['rx']! - _prevRx!) / dt) / 1024.0;
        txKbps = ((net['tx']! - _prevTx!) / dt) / 1024.0;
        if (rxKbps < 0) rxKbps = 0;
        if (txKbps < 0) txKbps = 0;
      }
    }
    _prevRx = net['rx'];
    _prevTx = net['tx'];
    _prevNetSample = now;

    int? storageUsed;
    if (widget.storageDir != null) {
      storageUsed = await _reader.computeDirectorySizeBytes(widget.storageDir!);
    }

    if (!mounted) return;
    setState(() {
      _stats = SystemStats(
        memTotalBytes: mem['total'],
        memAvailableBytes: mem['available'],
        cpuPercent: cpuPct,
        storageUsedBytes: storageUsed,
        storageTotalBytes: null, // not available without platform APIs
        rxBytesTotal: net['rx'],
        txBytesTotal: net['tx'],
        rxKbps: rxKbps,
        txKbps: txKbps,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _statCard(
        color1: Colors.cyanAccent,
        color2: Colors.tealAccent,
        icon: Icons.memory,
        title: 'Memory',
        value: _formatMemUsage(),
        progress: _stats.memUsagePercent != null ? (_stats.memUsagePercent! / 100.0) : null,
      ),
      _statCard(
        color1: Colors.greenAccent,
        color2: Colors.lightGreenAccent,
        icon: Icons.speed,
        title: 'CPU',
        value: _stats.cpuPercent != null ? '${_stats.cpuPercent!.toStringAsFixed(1)} %' : 'N/A',
        progress: _stats.cpuPercent != null ? (_stats.cpuPercent! / 100.0) : null,
      ),
      _statCard(
        color1: Colors.deepPurpleAccent,
        color2: Colors.purpleAccent,
        icon: Icons.storage,
        title: 'Storage',
        value: _stats.storageUsedBytes != null ? _formatBytes(_stats.storageUsedBytes!) : 'N/A',
        progress: null, // total unknown without platform APIs
      ),
      _statCard(
        color1: Colors.orangeAccent,
        color2: Colors.amberAccent,
        icon: Icons.network_check,
        title: 'Network',
        value: _formatNetRate(),
        progress: null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasFiniteWidth = constraints.maxWidth.isFinite;
        Widget rowWithSpacing(List<Widget> children) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: children[i],
                  ),
                ]
              ],
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasFiniteWidth)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards,
              )
            else
              // When width is unbounded (e.g., inside a horizontal scroller),
              // prefer Row to avoid giving RenderWrap infinite width.
              rowWithSpacing(cards),
          ],
        );
      },
    );
  }

  String _formatMemUsage() {
    final total = _stats.memTotalBytes;
    final avail = _stats.memAvailableBytes;
    if (total == null || avail == null) return 'N/A';
    final used = total - avail;
    return '${_formatBytes(used)} / ${_formatBytes(total)}';
  }

  String _formatNetRate() {
    final rx = _stats.rxKbps;
    final tx = _stats.txKbps;
    if (rx == null || tx == null) return 'N/A';
    return '⬇ ${rx.toStringAsFixed(1)} KB/s  ⬆ ${tx.toStringAsFixed(1)} KB/s';
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = bytes.toDouble();
    int idx = 0;
    while (v >= 1024 && idx < units.length - 1) {
      v /= 1024;
      idx++;
    }
    final s = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$s ${units[idx]}';
  }

  Widget _statCard({
    required Color color1,
    required Color color2,
    required IconData icon,
    required String title,
    required String value,
    double? progress,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color2.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(icon, color: Colors.black87),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                color: Colors.black87,
                backgroundColor: Colors.black.withOpacity(0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
