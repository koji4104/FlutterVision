// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttervision/camera_screen.dart';

// flutter test test/widget_test.dart
void main() {
   testWidgets('-- test', (WidgetTester tester) async {

    await tester.pumpWidget(
      MaterialApp(
      home: VideoListScreen(videoList:list))
    );
    
    await tester.pumpAndSettle();

    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('aaa'), findsOneWidget);

    await tester.tap(find.text('aaa'));
    await tester.pump();

    debugDumpApp();
  });
}
