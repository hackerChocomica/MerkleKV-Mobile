import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_demo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MerkleKV Integration Tests', () {
    testWidgets('App launches and displays correctly', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify core app structure
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      
      // Verify specific text content exists
      expect(find.text('MerkleKV Mobile Demo'), findsWidgets);
      expect(find.text('Package structure initialized successfully!'), findsOneWidget);
    });

    testWidgets('App widgets are properly structured', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app title in AppBar
      expect(find.widgetWithText(AppBar, 'MerkleKV Mobile Demo'), findsOneWidget);
      
      // Verify content structure
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Center), findsWidgets);
    });
  });
}