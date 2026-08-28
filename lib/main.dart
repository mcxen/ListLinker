import 'package:list_linker/l10n/alist_translations.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/router.dart';
import 'package:list_linker/util/app_http_overrides.dart';
import 'package:list_linker/util/log_utils.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/proxy.dart';
import 'package:list_linker/util/smb/smb_service.dart';
import 'package:list_linker/util/user_controller.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'database/alist_database_controller.dart';
import 'generated/color_schemes.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // sp初始化
  await SpUtil.getInstance();
  configureAppHttpOverrides();
  Log.init();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.grey.shade600),
              const SizedBox(height: 12),
              Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialRoute: NamedRouter.root,
      translations: AlistTranslations(),
      fallbackLocale: const Locale('en', 'US'),
      locale: PlatformDispatcher.instance.locale,
      getPages: AlistRouter.screens,
      builder: _routerBuilder,
      navigatorObservers: [FlutterSmartDialog.observer],
      defaultTransition: Transition.cupertino,
      scrollBehavior: AlistScrollBehavior(),
      title: "ALClient",
      theme: _lightTheme(context),
      darkTheme: _dartTheme(context),
    );
  }

  Widget _routerBuilder(BuildContext context, Widget? widget) {
    final smartDialogInit = FlutterSmartDialog.init();
    Get.put(AlistDatabaseController());
    Get.put(UserController());
    Get.put(ProxyServer());
    if (!Get.isRegistered<SmbService>()) {
      Get.put(SmbService()..init());
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
      child: RefreshConfiguration(
          headerBuilder: () {
            return ClassicHeader(
              idleText: Intl.pullRefresh_idleRefreshText.tr,
              releaseText: Intl.pullRefresh_canRefreshText.tr,
              refreshingText: Intl.pullRefresh_refreshingText.tr,
              completeText: Intl.pullRefresh_refreshCompleteText.tr,
              failedText: Intl.pullRefresh_refreshFailedText.tr,
            );
          },
          child: smartDialogInit(context, widget)),
    );
  }

  ThemeData _dartTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: darkColorScheme.primary,
        selectionColor: darkColorScheme.primary.withOpacity(0.35),
        selectionHandleColor: darkColorScheme.primary,
      ),
      dividerTheme: DividerTheme.of(context).copyWith(
        thickness: 0,
        space: 0,
      ),
      appBarTheme: AppBarTheme.of(context).copyWith(
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF1A1C1E),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
    );
  }

  ThemeData _lightTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      hintColor: const Color(0xFFBBBBBB),
      colorScheme: lightColorScheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: lightColorScheme.primary,
        selectionColor: lightColorScheme.primary.withOpacity(0.3),
        selectionHandleColor: lightColorScheme.primary,
      ),
      dividerTheme: DividerTheme.of(context).copyWith(
        thickness: 0,
        space: 0,
      ),
      appBarTheme: AppBarTheme.of(context).copyWith(
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
    );
  }
}

/// App-wide scrollbars on vertical scrollables (desktop/web and long lists).
class AlistScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        return Scrollbar(
          controller: details.controller,
          child: child,
        );
    }
  }
}
