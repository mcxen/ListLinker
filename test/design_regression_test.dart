import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sp_util/sp_util.dart';
import 'package:list_linker/widget/app_ui.dart';
import 'package:list_linker/widget/app_slidable.dart';
import 'package:list_linker/widget/spring_bottom_sheet.dart';

void main() {
  testWidgets('empty-state actions stay bounded in a wide list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              AppEmptyState(
                icon: Icons.dns,
                title: 'SMB',
                expand: false,
                primaryAction: FilledButton(
                  onPressed: () {},
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      lessThanOrEqualTo(360),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden swipe hint waits for the page to become active', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (context, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: AppSlidable(
              hintPreferenceKey: 'reviewHint',
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [SlidableAction(onPressed: (_) {}, label: 'Details')],
              ),
              child: const ListTile(title: Text('File')),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(SpUtil.getBool('reviewHint'), isNot(true));
    active.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(SpUtil.getBool('reviewHint'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spring sheet closes and returns its result', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showSpringBottomSheet<String>(
                    context: context,
                    builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).pop('done'),
                      child: const Text('Close'),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(result, 'done');
    expect(find.text('Close'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
