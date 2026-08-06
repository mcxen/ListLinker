import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:list_linker/entity/app_version_resp.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/net/dio_utils.dart';
import 'package:list_linker/router.dart';
import 'package:list_linker/screen/file_list/file_list_navigator.dart';
import 'package:list_linker/screen/recents_screen.dart';
import 'package:list_linker/screen/settings_screen.dart';
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
import 'package:sp_util/sp_util.dart';

import 'favorite_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
    _httpCheckAppVersion();
    _maybeShowWhatsNew();
  }

  void _onBottomNavTap(int idx) {
    HapticFeedback.selectionClick();
    if (idx == _currentPage) {
      // Reselect: scroll/pop the active tab to its root/top.
      if (idx == 0) {
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
    _pageController.jumpToPage(idx);
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
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          FileListNavigator(
            isInFileListStack: _currentPage == 0,
          ),
          const RecentsScreen(),
          const FavoriteScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: AlistBottomNavigationBar(
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
        currentIndex: _currentPage,
        type: BottomNavigationBarType.fixed,
        onTap: _onBottomNavTap,
        onLongPress: (int idx) {
          LogUtil.d("onDoubleTap: $idx");
          if (idx == 0 && _currentPage == 0) {
            Get.until((route) => route.isFirst,
                id: AlistRouter.fileListRouterStackId);
          } else {
            _pageController.jumpToPage(idx);
          }
        },
      ),
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
