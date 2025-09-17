import 'package:flutter/material.dart';import 'package:flutter/material.dart';

import 'package:merkle_kv_core/merkle_kv_core.dart';import 'package:merkle_kv_core/merkle_kv_core.dart';



void main() {/// Beta entrypoint with debug configurations

  runApp(const BetaApp());void main() {

}  runApp(const MerkleKVBetaApp());

}

class BetaApp extends StatelessWidget {

  const BetaApp({super.key});class MerkleKVBetaApp extends StatelessWidget {

  const MerkleKVBetaApp({super.key});

  @override

  Widget build(BuildContext context) {  @override

    return MaterialApp(  Widget build(BuildContext context) => MaterialApp(

      title: 'MerkleKV Beta',        title: 'MerkleKV (Beta)',

      theme: ThemeData(        theme: ThemeData(

        primarySwatch: Colors.orange,          primarySwatch: Colors.orange, // Beta theme

        useMaterial3: true,          useMaterial3: true,

      ),        ),

      home: const BetaHomePage(title: 'MerkleKV Beta Testing'),        home: const BetaHomePage(title: 'MerkleKV Mobile (Beta)'),

    );      );

  }}

}

class BetaHomePage extends StatefulWidget {

class BetaHomePage extends StatefulWidget {  const BetaHomePage({super.key, required this.title});

  const BetaHomePage({super.key, required this.title});

  final String title;

  final String title;

  @override

  @override  State<BetaHomePage> createState() => _BetaHomePageState();

  State<BetaHomePage> createState() => _BetaHomePageState();}

}

class _BetaHomePageState extends State<BetaHomePage> {

class _BetaHomePageState extends State<BetaHomePage> {  String _status = 'Initializing...';

  String _status = 'Ready to initialize Beta MerkleKV';  String _version = '1.0.0-beta.1';

  String _connectionInfo = '';

  @override

  @override  void initState() {

  void initState() {    super.initState();

    super.initState();    _initializeMerkleKV();

    _initializeMerkleKV();  }

  }

  Future<void> _initializeMerkleKV() async {

  Future<void> _initializeMerkleKV() async {    try {

    try {      setState(() {

      setState(() {        _status = 'Connecting to Beta MQTT broker...';

        _status = 'Connecting to Beta MQTT broker...';      });

      });

      // Beta-specific configuration

      // Beta-specific configuration      final config = MerkleKVConfig(

      final config = MerkleKVConfig(        mqttHost: 'test.mosquitto.org', // Beta test broker

        mqttHost: 'test.mosquitto.org', // Beta test broker        mqttPort: 1883,

        mqttPort: 1883,        clientId: 'merklekv_beta_${DateTime.now().millisecondsSinceEpoch}',

        clientId: 'merklekv_beta_${DateTime.now().millisecondsSinceEpoch}',        nodeId: 'beta_node_${DateTime.now().millisecondsSinceEpoch}',

        nodeId: 'beta_node_${DateTime.now().millisecondsSinceEpoch}',        topicPrefix: 'merklekv/beta',

        topicPrefix: 'merklekv/beta',        connectionTimeoutSeconds: 30,

        connectionTimeoutSeconds: 30,      );

      );

      setState(() {

      setState(() {        _status = 'Beta configuration loaded. Ready for testing!';

        _status = 'Beta configuration loaded. Ready for testing!';      });

      });    } catch (e) {

    } catch (e) {      setState(() {

      setState(() {        _status = 'Beta initialization failed: $e';

        _status = 'Beta initialization failed: $e';      });

      });    }

    }  }

  }

  @override

  @override  Widget build(BuildContext context) {

  Widget build(BuildContext context) {    return Scaffold(

    return Scaffold(      appBar: AppBar(

      appBar: AppBar(        backgroundColor: Colors.orange,

        backgroundColor: Colors.orange,        title: Text(widget.title),

        title: Text(widget.title),        actions: [

      ),          Container(

      body: Center(            padding: const EdgeInsets.all(8.0),

        child: Column(            child: const Center(

          mainAxisAlignment: MainAxisAlignment.center,              child: Text(

          children: <Widget>[                'BETA',

            const Icon(                style: TextStyle(

              Icons.bug_report,                  color: Colors.white,

              size: 64,                  fontWeight: FontWeight.bold,

              color: Colors.orange,                  fontSize: 12,

            ),                ),

            const SizedBox(height: 16),              ),

            const Text(            ),

              'MerkleKV Beta Version',          ),

              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),        ],

            ),      ),

            const SizedBox(height: 16),      body: Center(

            Text(        child: Column(

              'Status:',          mainAxisAlignment: MainAxisAlignment.center,

              style: Theme.of(context).textTheme.titleMedium,          children: <Widget>[

            ),            const Icon(

            const SizedBox(height: 8),              Icons.developer_mode,

            Container(              size: 100,

              padding: const EdgeInsets.all(16),              color: Colors.orange,

              margin: const EdgeInsets.symmetric(horizontal: 32),            ),

              decoration: BoxDecoration(            const SizedBox(height: 20),

                color: Colors.orange.shade50,            const Text(

                borderRadius: BorderRadius.circular(8),              'MerkleKV Mobile E2E Testing Framework',

                border: Border.all(color: Colors.orange.shade200),              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

              ),              textAlign: TextAlign.center,

              child: Text(            ),

                _status,            const SizedBox(height: 10),

                textAlign: TextAlign.center,            Text(

                style: const TextStyle(fontSize: 16),              'Version: $_version',

              ),              style: const TextStyle(fontSize: 14, color: Colors.grey),

            ),            ),

            const SizedBox(height: 16),            const SizedBox(height: 20),

            if (_connectionInfo.isNotEmpty) ...[            Container(

              Text(              padding: const EdgeInsets.all(16.0),

                'Connection Info:',              margin: const EdgeInsets.all(16.0),

                style: Theme.of(context).textTheme.titleMedium,              decoration: BoxDecoration(

              ),                color: Colors.orange.shade50,

              const SizedBox(height: 8),                border: Border.all(color: Colors.orange),

              Container(                borderRadius: BorderRadius.circular(8.0),

                padding: const EdgeInsets.all(12),              ),

                margin: const EdgeInsets.symmetric(horizontal: 32),              child: Column(

                decoration: BoxDecoration(                children: [

                  color: Colors.grey.shade100,                  const Text(

                  borderRadius: BorderRadius.circular(8),                    'Beta Features:',

                ),                    style: TextStyle(fontWeight: FontWeight.bold),

                child: Text(                  ),

                  _connectionInfo,                  const SizedBox(height: 8),

                  textAlign: TextAlign.center,                  const Text('• 3-Layer E2E Testing Orchestrator'),

                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),                  const Text('• Mobile Lifecycle Test Scenarios'),

                ),                  const Text('• Network State Testing'),

              ),                  const Text('• Convergence Testing Framework'),

            ],                  const Text('• Cloud Device Integration'),

            const SizedBox(height: 32),                  const SizedBox(height: 16),

            ElevatedButton(                  Text(

              onPressed: _initializeMerkleKV,                    'Status: $_status',

              style: ElevatedButton.styleFrom(                    style: const TextStyle(fontStyle: FontStyle.italic),

                backgroundColor: Colors.orange,                    textAlign: TextAlign.center,

                foregroundColor: Colors.white,                  ),

              ),                ],

              child: const Text('Restart Beta Test'),              ),

            ),            ),

          ],          ],

        ),        ),

      ),      ),

    );      floatingActionButton: FloatingActionButton(

  }        onPressed: _initializeMerkleKV,

}        tooltip: 'Reinitialize',
        backgroundColor: Colors.orange,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}