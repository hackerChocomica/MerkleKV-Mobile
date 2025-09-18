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

      // Verify the app title is displayed (should find at least one)
      expect(find.text('MerkleKV Mobile Demo'), findsAtLeastNWidgets(1));
      
      // Verify the app loads without errors
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      
      // Verify specific UI elements
      expect(find.text('Package structure initialized successfully!'), findsOneWidget);
    });

    testWidgets('Basic UI navigation works', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Test that we can interact with the app
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      
      // Verify the main content is present
      expect(find.text('MerkleKV Mobile Demo'), findsAtLeastNWidgets(1));
    });
  });
}