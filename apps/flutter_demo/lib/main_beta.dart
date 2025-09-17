import 'package:flutter/material.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';

void main() {
  runApp(const BetaApp());
}

class BetaApp extends StatelessWidget {
  const BetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MerkleKV Beta',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BetaHomePage(title: 'MerkleKV Beta Test'),
    );
  }
}

class BetaHomePage extends StatefulWidget {
  const BetaHomePage({super.key, required this.title});

  final String title;

  @override
  State<BetaHomePage> createState() => _BetaHomePageState();
}

class _BetaHomePageState extends State<BetaHomePage> {
  String _status = 'Initializing...';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _initializeMerkleKV();
  }

  void _initializeMerkleKV() async {
    try {
      // Initialize MerkleKV configuration
      MerkleKVConfig(
        nodeId: 'beta-test-node',
        clientId: 'beta-test-client',
        mqttHost: 'localhost',
        mqttPort: 1883,
        topicPrefix: 'merkle_kv/beta',
        connectionTimeoutSeconds: 30,
      );

      setState(() {
        _status = 'MerkleKV initialized successfully';
        _version = '1.0.0-beta';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to initialize MerkleKV: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.storage,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              'MerkleKV Beta Status',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_version.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Version: $_version',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _initializeMerkleKV,
              child: const Text('Reinitialize MerkleKV'),
            ),
          ],
        ),
      ),
    );
  }
}
