// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_demo/main.dart';

void main() {
  testWidgets('MerkleKV app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app shows the correct title.
    expect(find.text('MerkleKV Mobile Demo'), findsWidgets);
    // Verify main dashboard and log sections are present.
    expect(find.text('Live System Dashboard'), findsOneWidget);
    expect(find.text('Connection Log'), findsOneWidget);

    // Verify that the app bar is present.
    expect(find.byType(AppBar), findsOneWidget);
    
    // Verify that the scaffold is present.
    expect(find.byType(Scaffold), findsOneWidget);
    
    // Verify that the app uses Material design.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
