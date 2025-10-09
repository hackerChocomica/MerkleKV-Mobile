import 'dart:io';
import 'package:flutter/material.dart';
import 'widgets/system_stats_panel.dart';
import 'widgets/rich_console_view.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

    @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MerkleKV Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'MerkleKV Mobile Demo'),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final StreamConnectionLogger _logger;

  @override
  void initState() {
    super.initState();
    _logger = StreamConnectionLogger(tag: 'Dashboard', mirrorToConsole: false);
    // Seed some demo logs to visualize console quickly
    Future.microtask(() {
      _logger.info('Welcome to MerkleKV Mobile');
      _logger.debug('Boot sequence initialized');
      _logger.warn('Battery saver active; background sync paused');
      _logger.error('Handshake failed (demo)', Exception('certificate expired'));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.bolt, color: Colors.amber),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dashboard_customize, color: Colors.cyanAccent),
                      SizedBox(width: 8),
                      Text('Live System Dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // System stats
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SystemStatsPanel(
                            refreshInterval: const Duration(seconds: 1),
                            storageDir: Directory.systemTemp, // demo dir
                            autoRefresh: true, // normal app run keeps refreshing
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Vibrant log console
                  Expanded(
                    flex: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.terminal, color: Colors.greenAccent),
                                SizedBox(width: 8),
                                Text('Connection Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: RichConsoleView(
                                logger: _logger,
                                levels: const {'DEBUG', 'INFO', 'WARN', 'ERROR'},
                                tag: 'Dashboard',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
