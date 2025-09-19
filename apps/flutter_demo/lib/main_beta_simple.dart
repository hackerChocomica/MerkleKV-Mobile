import 'package:flutter/material.dart';

void main() {
  runApp(const MerkleKVBetaApp());
}

class MerkleKVBetaApp extends StatelessWidget {
  const MerkleKVBetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MerkleKV (Beta)',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MerkleKVHomePage(),
    );
  }
}

class MerkleKVHomePage extends StatefulWidget {
  const MerkleKVHomePage({super.key});

  @override
  State<MerkleKVHomePage> createState() => _MerkleKVHomePageState();
}

class _MerkleKVHomePageState extends State<MerkleKVHomePage> {
  bool _isMerkleKVConnected = false;
  String _connectionStatus = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _initializeMerkleKV();
  }

  Future<void> _initializeMerkleKV() async {
    try {
      // Simple initialization without actual connection for build purposes
      setState(() {
        _isMerkleKVConnected = true;
        _connectionStatus = 'Connected (Beta)';
      });
    } catch (e) {
      setState(() {
        _isMerkleKVConnected = false;
        _connectionStatus = 'Connection failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MerkleKV Mobile (Beta)'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              _isMerkleKVConnected ? Icons.cloud_done : Icons.cloud_off,
              size: 64,
              color: _isMerkleKVConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Status: $_connectionStatus',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                children: [
                  Text(
                    '🧪 BETA VERSION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Version: 1.0.0-beta.1',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Build: 10001',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Package: com.merklekv.mobile.beta',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeMerkleKV,
              child: const Text('Test Connection'),
            ),
          ],
        ),
      ),
    );
  }
}