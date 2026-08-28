import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:list_linker/entity/app_version_resp.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/net/dio_utils.dart';
import 'package:list_linker/router.dart';
import 'package:list_linker/screen/file_list/file_list_navigator.dart';
import 'package:list_linker/screen/local_storage_browser_screen.dart';
import 'package:list_linker/screen/recents_screen.dart';
import 'package:list_linker/screen/settings_screen.dart';
import 'package:list_linker/screen/smb/smb_workspace_screen.dart';
import 'package:list_linker/util/constant.dart';
import 'package:list_linker/util/global.dart';
import 'package:list_linker/widget/bottom_navigation_bar.dart';
import 'package:list_linker/widget/update_dialog.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'favorite_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeDestination {
  cloud,
  local,
  smb,
  recents,
  favorites,
  settings,
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _desktopNavigationBreakpoint = 760;
  static const _mobileDestinations = [
    _HomeDestination.cloud,
    _HomeDestination.recents,
    _HomeDestination.favorites,
    _HomeDestination.settings,
  ];

  static const _offlineDestinations = [
    _HomeDestination.local,
    _HomeDestination.smb,
    _HomeDestination.settings,
  ];

  _HomeDestination _currentDestination = _HomeDestination.cloud;
  late final bool _offlineMode;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _offlineMode = args is Map && args['offline'] == true;
    if (_offlineMode) {
      _currentDestination = _HomeDestination.local;
    } else {
      _httpCheckAppVersion();
    }
    _maybeShowWhatsNew();
  }

  void _onDestinationSelected(_HomeDestination destination) {
    HapticFeedback.selectionClick();
    if (destination == _currentDestination) {
      if (destination == _HomeDestination.cloud) {
        Get.until((route) => route.isFirst,
            id: AlistRouter.fileListRouterStackId);
      } else {
        final primary = PrimaryScrollController.maybeOf(context);
        if (primary != null && primary.hasClients) {
          primary.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
      return;
    }
    setState(() => _currentDestination = destination);
  }

  Future<void> _maybeShowWhatsNew() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final lastSeen = SpUtil.getString(AlistConstant.lastSeenVersion) ?? '';
    if (lastSeen == version) return;
    // Fresh install: remember version without dialog.
    if (lastSeen.isEmpty) {
      await SpUtil.putString(AlistConstant.lastSeenVersion, version);
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(Intl.appName.tr),
          content: Text(
            'v$version\n\n'
            '• Smoother image loading and list scrolling\n'
            '• Clearer keyboard and form actions\n'
            '• Swipe actions hint and haptic feedback\n'
            '• Friendlier error and version display',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(Intl.downloadManager_downloadTipDialog_iKnow.tr),
            ),
          ],
        );
      },
    );
    await SpUtil.putString(AlistConstant.lastSeenVersion, version);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopNavigation = _offlineMode ||
            constraints.maxWidth >= _desktopNavigationBreakpoint;
        final effectiveDestination = useDesktopNavigation ||
                _mobileDestinations.contains(_currentDestination)
            ? _currentDestination
            : _HomeDestination.cloud;
        final pages = <Widget>[
          _offlineMode
              ? const SizedBox.shrink()
              : FileListNavigator(
                  isInFileListStack:
                      effectiveDestination == _HomeDestination.cloud,
                ),
          const LocalStorageBrowserScreen(embedded: true),
          const SmbWorkspaceScreen(),
          const RecentsScreen(),
          const FavoriteScreen(),
          const SettingsScreen(),
        ];
        final content = IndexedStack(
          index: effectiveDestination.index,
          children: pages,
        );

        return Scaffold(
          body: useDesktopNavigation
              ? Row(
                  children: [
                    _buildDesktopMenu(context),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withOpacity(0.55),
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar:
              useDesktopNavigation ? null : _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildDesktopMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destinations =
        _offlineMode ? _offlineDestinations : _HomeDestination.values;

    return SizedBox(
      width: 224,
      child: Material(
        color: scheme.surfaceContainerHighest.withOpacity(0.32),
        child: NavigationRail(
          extended: true,
          minExtendedWidth: 224,
          selectedIndex: destinations.indexOf(_currentDestination),
          groupAlignment: -1,
          useIndicator: true,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 22),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                Intl.appName.tr,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          onDestinationSelected: (index) =>
              _onDestinationSelected(destinations[index]),
          destinations: destinations.map(_buildRailDestination).toList(),
        ),
      ),
    );
  }

  NavigationRailDestination _buildRailDestination(
    _HomeDestination destination,
  ) {
    return switch (destination) {
      _HomeDestination.cloud => NavigationRailDestination(
          icon: const Icon(Icons.cloud_outlined),
          selectedIcon: const Icon(Icons.cloud_rounded),
          label: Text(Intl.screenName_home.tr),
        ),
      _HomeDestination.local => NavigationRailDestination(
          icon: const Icon(Icons.folder_outlined),
          selectedIcon: const Icon(Icons.folder_rounded),
          label: Text(Intl.screenName_localFiles.tr),
        ),
      _HomeDestination.smb => NavigationRailDestination(
          icon: const Icon(Icons.dns_outlined),
          selectedIcon: const Icon(Icons.dns_rounded),
          label: Text(Intl.screenName_smb.tr),
        ),
      _HomeDestination.recents => NavigationRailDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history_rounded),
          label: Text(Intl.screenName_recents.tr),
        ),
      _HomeDestination.favorites => NavigationRailDestination(
          icon: const Icon(Icons.star_outline_rounded),
          selectedIcon: const Icon(Icons.star_rounded),
          label: Text(Intl.screenName_favorite.tr),
        ),
      _HomeDestination.settings => NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: Text(Intl.screenName_settings.tr),
        ),
    };
  }

  Widget _buildBottomNavigationBar() {
    final effectiveDestination =
        _mobileDestinations.contains(_currentDestination)
            ? _currentDestination
            : _HomeDestination.cloud;
    return AlistBottomNavigationBar(
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: const Icon(Icons.folder_rounded),
          label: Intl.screenName_home.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.timelapse_rounded),
          label: Intl.screenName_recents.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.star_rounded),
          label: Intl.screenName_favorite.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_rounded),
          label: Intl.screenName_settings.tr,
        )
      ],
      currentIndex: _mobileDestinations.indexOf(effectiveDestination),
      type: BottomNavigationBarType.fixed,
      onTap: (index) => _onDestinationSelected(_mobileDestinations[index]),
      onLongPress: (int idx) {
        LogUtil.d("onDoubleTap: $idx");
        final destination = _mobileDestinations[idx];
        if (destination == _HomeDestination.cloud &&
            _currentDestination == _HomeDestination.cloud) {
          Get.until((route) => route.isFirst,
              id: AlistRouter.fileListRouterStackId);
        } else {
          _onDestinationSelected(destination);
        }
      },
    );
  }

  Future<void> _httpCheckAppVersion() async {
    var packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;
    String url =
        "https://${Global.configServerHost}/app/version.json?version=$version";
    DioUtils.instance.requestForString(Method.get, url,
        onSuccess: (string) async {
      if (string == null || string.isEmpty) return;
      Map<String, dynamic> json = jsonDecode(string);
      var appVersionResp = AppVersionResp.fromJson(json);
      String respVersion;
      if (Platform.isIOS) {
        respVersion = appVersionResp.ios.version;
      } else {
        respVersion = appVersionResp.android.version;
      }
      if (_version2Int(respVersion) > _version2Int(version)) {
        _showUpdateDialog(appVersionResp);
      }
    });
  }

  int _version2Int(String version) {
    var versionInt = 0;
    var arr = version.split(".");
    for (int i = 0; i < arr.length; i++) {
      versionInt += int.parse(arr[i]) * pow(100, arr.length - i - 1).toInt();
    }
    return versionInt;
  }

  void _showUpdateDialog(AppVersionResp appVersion) {
    String version =
        Platform.isIOS ? appVersion.ios.version : appVersion.android.version;
    String? ignoreVersion = SpUtil.getString(AlistConstant.ignoreAppVersion);
    if (version == ignoreVersion) {
      return;
    }
    SmartDialog.show(
      clickMaskDismiss: false,
      builder: (_) => UpdateDialog(appVersion: appVersion),
    );
  }
}
