import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/util/named_router.dart';

final ValueNotifier<String> currentRouteName = ValueNotifier(NamedRouter.root);

String titleForRoute(String route) {
  final page = switch (route) {
    NamedRouter.login => Intl.screenName_login.tr,
    NamedRouter.home || NamedRouter.fileList => Intl.screenName_home.tr,
    NamedRouter.settings => Intl.screenName_settings.tr,
    NamedRouter.donate => Intl.screenName_donate.tr,
    NamedRouter.about => Intl.screenName_about.tr,
    NamedRouter.uploadingFiles => Intl.screenName_uploadingFiles.tr,
    NamedRouter.account => Intl.settingsScreen_item_account.tr,
    NamedRouter.downloadManager => Intl.downloadManagerScreen_title.tr,
    NamedRouter.cacheManager => Intl.screenName_cacheManagement.tr,
    NamedRouter.playerSettings => Intl.screenName_playerSettings.tr,
    NamedRouter.localVideos => Intl.screenName_localVideos.tr,
    NamedRouter.localStorageBrowser => Intl.screenName_localFiles.tr,
    NamedRouter.smb ||
    NamedRouter.smbBrowser ||
    NamedRouter.smbScan =>
      Intl.screenName_smb.tr,
    NamedRouter.gallery => 'Gallery',
    NamedRouter.videoPlayer => 'Video',
    NamedRouter.audioPlayer => 'Audio',
    NamedRouter.pdfReader => 'PDF',
    NamedRouter.fileReader => 'File',
    NamedRouter.fileSearch => 'Search',
    NamedRouter.web => 'Web',
    _ => null,
  };
  final app = Intl.appName.tr;
  return page == null ? app : '$page · $app';
}

class RouteTitle extends StatelessWidget {
  const RouteTitle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentRouteName,
      builder: (context, route, child) {
        return Title(
          title: titleForRoute(route),
          color: Theme.of(context).colorScheme.surface,
          child: child!,
        );
      },
      child: child,
    );
  }
}
