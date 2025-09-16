import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_demo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MerkleKV Integration Tests', () {
    testWidgets('App launches and displays title', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify the app title is displayed
      expect(find.text('MerkleKV Mobile Demo'), findsOneWidget);
      
      // Verify the app loads without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Basic UI navigation works', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Test that we can interact with the app
      // (This is a placeholder - real tests would interact with MerkleKV features)
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}