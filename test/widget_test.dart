import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_linker/widget/alist_scaffold.dart';

void main() {
  testWidgets('macOS scaffold renders its title and content',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS, useMaterial3: true),
        home: const AlistScaffold(
          appbarTitle: Text('ListLinker'),
          body: Center(child: Text('Files')),
        ),
      ),
    );

    expect(find.text('ListLinker'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
