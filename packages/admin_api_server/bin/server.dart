import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:merkle_kv_core/merkle_kv_core.dart' as mkv;
import 'package:shelf/shelf.dart' as sh;
import 'package:shelf/shelf_io.dart' as sh_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as cors;
import 'package:shelf_router/shelf_router.dart' as rt;

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  // Shared logger for streaming logs to websocket-ish via SSE
  final logger = mkv.StreamConnectionLogger(tag: 'AdminAPI', mirrorToConsole: true);

  final app = rt.Router();

  // Health
  app.get('/health', (sh.Request req) => sh.Response.ok(jsonEncode({'status': 'ok'}), headers: {'content-type': 'application/json'}));

  // System stats (Linux/Android via /proc)
  // Optional query params: dir=/path/to/measure&maxEntries=5000
  app.get('/stats/system', (sh.Request req) async {
    final q = req.requestedUri.queryParameters;
    final dir = q['dir'];
    final maxEntries = int.tryParse(q['maxEntries'] ?? '5000') ?? 5000;
    final stats = await _readSystemStats(dirPath: dir, maxEntries: maxEntries);
    return sh.Response.ok(jsonEncode(stats), headers: {'content-type': 'application/json'});
  });

  // Current process stats (RSS memory; raw CPU counters)
  app.get('/stats/process', (sh.Request req) async {
    final stats = await _readProcessStats();
    return sh.Response.ok(jsonEncode(stats), headers: {'content-type': 'application/json'});
  });

  // MQTT config echo (for validation)
  app.post('/config/validate', (sh.Request req) async {
    final body = await req.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    try {
      final cfg = mkv.MerkleKVConfig(
        mqttHost: data['mqttHost'] ?? 'localhost',
        mqttPort: (data['mqttPort'] ?? 1883) as int,
        mqttUseTls: data['mqttUseTls'] == true,
        clientId: data['clientId'] ?? 'admin-api',
        nodeId: data['nodeId'] ?? 'admin-node',
        username: data['username'],
        password: data['password'],
        topicPrefix: data['topicPrefix'] ?? 'merkle_kv',
      );
      return sh.Response.ok(jsonEncode({'valid': true, 'clientId': cfg.clientId}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return sh.Response(400, body: jsonEncode({'valid': false, 'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  });

  // SSE endpoint for logs
  app.get('/logs/stream', (sh.Request req) {
    final controller = StreamController<List<int>>();
    void write(String data) {
      controller.add(utf8.encode('data: $data\n\n'));
    }

    final sub = logger.stream.listen((e) {
      write(jsonEncode(e.toJson()));
    });

    // Emit a hello and keepalive pings
    write(jsonEncode({'ts': DateTime.now().toIso8601String(), 'level': 'INFO', 'message': 'SSE connected'}));
    final ping = Timer.periodic(const Duration(seconds: 10), (_) {
      write(jsonEncode({'ts': DateTime.now().toIso8601String(), 'level': 'DEBUG', 'message': 'ping'}));
    });

    controller.onCancel = () {
      sub.cancel();
      ping.cancel();
    };

    return sh.Response.ok(controller.stream, headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
  });

  // Recent logs as JSON (buffer snapshot). Optional query param: limit
  app.get('/logs/recent', (sh.Request req) {
    final limit = int.tryParse(req.requestedUri.queryParameters['limit'] ?? '') ?? 200;
    final buf = logger.bufferSnapshot;
    final start = buf.length > limit ? buf.length - limit : 0;
    final sliced = buf.sublist(start).map((e) => e.toJson()).toList(growable: false);
    return sh.Response.ok(jsonEncode({'count': sliced.length, 'entries': sliced}), headers: {'content-type': 'application/json'});
  });

  // Clear buffered logs
  app.post('/logs/clear', (sh.Request req) async {
    logger.clear();
    return sh.Response.ok(jsonEncode({'cleared': true}), headers: {'content-type': 'application/json'});
  });

  // Wrap with CORS + JSON content type
  final handler = const sh.Pipeline()
      .addMiddleware(sh.logRequests())
      .addMiddleware(cors.corsHeaders())
      .addHandler(app);

  final server = await sh_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Admin API listening on port ${server.port}');
}

Future<Map<String, dynamic>> _readSystemStats({String? dirPath, int maxEntries = 5000}) async {
  int? memTotal;
  int? memAvail;
  double? cpu;
  int? rx;
  int? tx;
  int? storageUsed;

  try {
    final lines = await File('/proc/meminfo').readAsLines();
    for (final l in lines) {
      if (l.startsWith('MemTotal:')) {
        memTotal = int.tryParse(l.split(RegExp(r'\s+'))[1])?.let((kb) => kb * 1024);
      }
      if (l.startsWith('MemAvailable:')) {
        memAvail = int.tryParse(l.split(RegExp(r'\s+'))[1])?.let((kb) => kb * 1024);
      }
    }
  } catch (_) {}

  try {
    final s = await File('/proc/stat').readAsLines();
    final l = s.firstWhere((e) => e.startsWith('cpu '));
    final p = l.split(RegExp(r'\s+'));
    final user = int.tryParse(p[1]) ?? 0;
    final nice = int.tryParse(p[2]) ?? 0;
    final system = int.tryParse(p[3]) ?? 0;
    final idle = int.tryParse(p[4]) ?? 0;
    final iowait = int.tryParse(p[5]) ?? 0;
    final irq = int.tryParse(p[6]) ?? 0;
    final softirq = int.tryParse(p[7]) ?? 0;
    final steal = p.length > 8 ? (int.tryParse(p[8]) ?? 0) : 0;
    final total = user + nice + system + idle + iowait + irq + softirq + steal;
    final idleAll = idle + iowait;
    // A single snapshot; client can compute deltas over time, or we expose only raw totals here.
    cpu = total > 0 ? (1.0 - (idleAll / total)) * 100.0 : null;
  } catch (_) {}

  try {
    final lines = await File('/proc/net/dev').readAsLines();
    int rxSum = 0;
    int txSum = 0;
    for (final l in lines.skip(2)) {
      final parts = l.split(':');
      if (parts.length != 2) continue;
      final iface = parts[0].trim();
      if (iface == 'lo') continue;
      final fields = parts[1].trim().split(RegExp(r'\s+'));
      if (fields.length >= 16) {
        rxSum += int.tryParse(fields[0]) ?? 0;
        txSum += int.tryParse(fields[8]) ?? 0;
      }
    }
    rx = rxSum;
    tx = txSum;
  } catch (_) {}

  // Optional storage directory measurement (best-effort)
  if (dirPath != null && dirPath.isNotEmpty) {
    try {
      int total = 0;
      int count = 0;
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final ent in dir.list(recursive: true, followLinks: false)) {
          if (count++ > maxEntries) break;
          if (ent is File) {
            final st = await ent.stat();
            total += st.size;
          }
        }
        storageUsed = total;
      }
    } catch (_) {}
  }

  return {
    'memory': {
      'totalBytes': memTotal,
      'availableBytes': memAvail,
    },
    'cpu': {
      'utilizationPercentApprox': cpu,
    },
    'network': {
      'rxBytesTotal': rx,
      'txBytesTotal': tx,
    },
    if (storageUsed != null) 'storage': {'usedBytes': storageUsed, 'path': dirPath},
  };
}

Future<Map<String, dynamic>> _readProcessStats() async {
  int? rssBytes;
  int? utime;
  int? stime;
  try {
    final status = await File('/proc/self/status').readAsLines();
    for (final l in status) {
      if (l.startsWith('VmRSS:')) {
        final kb = int.tryParse(l.split(RegExp(r'\\s+'))[1]);
        if (kb != null) rssBytes = kb * 1024;
        break;
      }
    }
  } catch (_) {}

  try {
    final stat = await File('/proc/self/stat').readAsString();
    final parts = stat.split(RegExp(r'\\s+'));
    if (parts.length > 17) {
      utime = int.tryParse(parts[13]); // 14th field
      stime = int.tryParse(parts[14]); // 15th field
    }
  } catch (_) {}

  return {
    'memory': {'rssBytes': rssBytes},
    'cpu': {'utime': utime, 'stime': stime, 'ticks': 'jiffies'},
  };
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
