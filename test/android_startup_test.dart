import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:list_linker/database/alist_database_controller.dart';
import 'package:list_linker/main.dart' as app;
import 'package:list_linker/screen/splash_screen.dart';
import 'package:list_linker/util/alist_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingDatabaseController extends AlistDatabaseController {
  final _ready = Completer<void>();

  @override
  Future<void> init() => _ready.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android reaches the first Flutter frame without desktop mpv',
      (tester) async {
    final errorWidgetBuilder = ErrorWidget.builder;
    final httpOverrides = HttpOverrides.current;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    Get.put<AlistDatabaseController>(_PendingDatabaseController());

    try {
      await tester.runAsync(app.main);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(tester.takeException(), isNull);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ErrorWidget.builder = errorWidgetBuilder;
      HttpOverrides.global = httpOverrides;
      debugDefaultTargetPlatformOverride = null;
      Get.reset();
    }
  });

  test('Dart calls the method channel registered by Android', () async {
    final nativeSource = File(
      'android/app/src/main/kotlin/com/example/listlinker/plugin/AlistPlugin.kt',
    ).readAsStringSync();
    final channelName = RegExp(
      r'MethodChannel\(binding.binaryMessenger, "([^"]+)"\)',
    ).firstMatch(nativeSource)!.group(1)!;
    final channel = MethodChannel(channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isScopedStorage');
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(await AlistPlugin.isScopedStorage(), isTrue);
  });
}
