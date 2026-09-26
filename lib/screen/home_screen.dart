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
import 'package:list_linker/util/haptics_helper.dart';
import 'package:list_linker/widget/bottom_navigation_bar.dart';
import 'package:list_linker/widget/update_dialog.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'favorite_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeDestination { cloud, local, smb, recents, favorites, settings }

class _HomeScreenState extends State<HomeScreen> {
  static const double _desktopNavigationBreakpoint = 760;
  static const double _desktopPanelRadius = 18;
  static const double _desktopPanelGap = 12;
  static const double _desktopMenuExpandedWidth = 224;
  static const double _desktopMenuCollapsedWidth = 72;
  static const Duration _desktopMenuAnimationDuration = Duration(
    milliseconds: 240,
  );
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
  bool _desktopMenuCollapsed = false;
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

  void _onDestinationSelected(
    _HomeDestination destination, {
    bool emitHaptic = true,
  }) {
    if (emitHaptic) HapticsHelper.selection();
    if (destination == _currentDestination) {
      if (destination == _HomeDestination.cloud) {
        Get.until(
          (route) => route.isFirst,
          id: AlistRouter.fileListRouterStackId,
        );
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
    PackageInfo packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      return;
    }
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
        final useDesktopNavigation =
            _offlineMode ||
            constraints.maxWidth >= _desktopNavigationBreakpoint;
        final effectiveDestination =
            useDesktopNavigation ||
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
        final destinationTitle = switch (effectiveDestination) {
          _HomeDestination.cloud => Intl.screenName_home.tr,
          _HomeDestination.local => Intl.screenName_localFiles.tr,
          _HomeDestination.smb => Intl.screenName_smb.tr,
          _HomeDestination.recents => Intl.screenName_recents.tr,
          _HomeDestination.favorites => Intl.screenName_favorite.tr,
          _HomeDestination.settings => Intl.screenName_settings.tr,
        };
        final content = Title(
          title: '$destinationTitle · ${Intl.appName.tr}',
          color: Theme.of(context).colorScheme.surface,
          child: IndexedStack(
            index: effectiveDestination.index,
            children: [
              for (var index = 0; index < pages.length; index++)
                TickerMode(
                  enabled: index == effectiveDestination.index,
                  child: pages[index],
                ),
            ],
          ),
        );

        return Scaffold(
          backgroundColor: useDesktopNavigation
              ? Theme.of(context).colorScheme.surfaceContainerLow
              : null,
          body: useDesktopNavigation
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(_desktopPanelGap),
                    child: Row(
                      children: [
                        _buildDesktopMenu(context),
                        const SizedBox(width: _desktopPanelGap),
                        Expanded(child: _DesktopPanel(child: content)),
                      ],
                    ),
                  ),
                )
              : content,
          bottomNavigationBar: useDesktopNavigation
              ? null
              : _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildDesktopMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destinations = _offlineMode
        ? _offlineDestinations
        : _HomeDestination.values;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _desktopMenuAnimationDuration;

    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeInOutCubic,
      width: _desktopMenuCollapsed
          ? _desktopMenuCollapsedWidth
          : _desktopMenuExpandedWidth,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_desktopPanelRadius),
          side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationRail(
          backgroundColor: Colors.transparent,
          extended: !_desktopMenuCollapsed,
          minWidth: _desktopMenuCollapsedWidth,
          minExtendedWidth: _desktopMenuExpandedWidth,
          selectedIndex: destinations.indexOf(_currentDestination),
          groupAlignment: -1,
          useIndicator: true,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
            child: SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: animationDuration,
                        curve: Curves.easeOut,
                        opacity: _desktopMenuCollapsed ? 0 : 1,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 40),
                            child: Text(
                              Intl.appName.tr,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedAlign(
                      duration: animationDuration,
                      curve: Curves.easeInOutCubic,
                      alignment: _desktopMenuCollapsed
                          ? Alignment.center
                          : Alignment.centerRight,
                      child: IconButton(
                        tooltip: _desktopMenuCollapsed
                            ? Intl.navigation_expand.tr
                            : Intl.navigation_collapse.tr,
                        onPressed: () {
                          HapticsHelper.selection();
                          setState(() {
                            _desktopMenuCollapsed = !_desktopMenuCollapsed;
                          });
                        },
                        icon: AnimatedRotation(
                          duration: animationDuration,
                          curve: Curves.easeInOutCubic,
                          turns: _desktopMenuCollapsed ? 0.5 : 0,
                          child: const Icon(Icons.chevron_left_rounded),
                        ),
                      ),
                    ),
                  ),
                ],
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
        ),
      ],
      currentIndex: _mobileDestinations.indexOf(effectiveDestination),
      type: BottomNavigationBarType.fixed,
      onTap: (index) => _onDestinationSelected(_mobileDestinations[index]),
      onLongPress: (int idx) {
        HapticsHelper.medium();
        LogUtil.d("onDoubleTap: $idx");
        final destination = _mobileDestinations[idx];
        if (destination == _HomeDestination.cloud &&
            _currentDestination == _HomeDestination.cloud) {
          Get.until(
            (route) => route.isFirst,
            id: AlistRouter.fileListRouterStackId,
          );
        } else {
          _onDestinationSelected(destination, emitHaptic: false);
        }
      },
    );
  }

  Future<void> _httpCheckAppVersion() async {
    PackageInfo packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      return;
    }
    String version = packageInfo.version;
    String url =
        "https://${Global.configServerHost}/app/version.json?version=$version";
    DioUtils.instance.requestForString(
      Method.get,
      url,
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
      },
    );
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
    String version = Platform.isIOS
        ? appVersion.ios.version
        : appVersion.android.version;
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

class _DesktopPanel extends StatelessWidget {
  const _DesktopPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          _HomeScreenState._desktopPanelRadius,
        ),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
