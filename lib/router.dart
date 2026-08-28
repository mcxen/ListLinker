import 'package:list_linker/screen/aboute_screen.dart';
import 'package:list_linker/screen/account_screen.dart';
import 'package:list_linker/screen/audio_player_screen.dart';
import 'package:list_linker/screen/cache_manager.dart';
import 'package:list_linker/screen/donate_screen.dart';
import 'package:list_linker/screen/desktop_video_player_screen.dart';
import 'package:list_linker/screen/download_manager_screen.dart';
import 'package:list_linker/screen/file_list/file_list_screen.dart';
import 'package:list_linker/screen/file_reader_screen.dart';
import 'package:list_linker/screen/file_search_screen.dart';
import 'package:list_linker/screen/gallery_screen.dart';
import 'package:list_linker/screen/home_screen.dart';
import 'package:list_linker/screen/login_screen.dart';
import 'package:list_linker/screen/pdf_reader_screen.dart';
import 'package:list_linker/screen/local_storage_browser_screen.dart';
import 'package:list_linker/screen/local_video_screen.dart';
import 'package:list_linker/screen/player_settings_screen.dart';
import 'package:list_linker/screen/settings_screen.dart';
import 'package:list_linker/screen/smb/smb_browser_screen.dart';
import 'package:list_linker/screen/smb/smb_list_screen.dart';
import 'package:list_linker/screen/smb/smb_scan_screen.dart';
import 'package:list_linker/screen/splash_screen.dart';
import 'package:list_linker/screen/uploading_files_screen.dart';
import 'package:list_linker/screen/video_player_screen.dart';
import 'package:list_linker/screen/web_screen.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:get/get.dart';

class AlistRouter {
  static const fileListRouterStackId = 1;
  static const fileListCopyMoveRouterStackId = 2;

  static final List<GetPage> screens = [
    GetPage(name: NamedRouter.root, page: () => const SplashScreen()),
    GetPage(name: NamedRouter.login, page: () => LoginScreen()),
    GetPage(name: NamedRouter.home, page: () => const HomeScreen()),
    GetPage(name: NamedRouter.fileList, page: () => FileListWrapper()),
    GetPage(name: NamedRouter.settings, page: () => const SettingsScreen()),
    GetPage(
      name: NamedRouter.videoPlayer,
      page: () => GetPlatform.isDesktop
          ? const DesktopVideoPlayerScreen()
          : const VideoPlayerScreen(),
    ),
    GetPage(name: NamedRouter.audioPlayer, page: () => AudioPlayerScreen()),
    GetPage(name: NamedRouter.donate, page: () => const DonateScreen()),
    GetPage(name: NamedRouter.about, page: () => const AboutScreen()),
    GetPage(name: NamedRouter.gallery, page: () => GalleryScreen()),
    GetPage(name: NamedRouter.fileReader, page: () => FileReaderScreen()),
    GetPage(name: NamedRouter.web, page: () => const WebScreen()),
    GetPage(name: NamedRouter.pdfReader, page: () => PdfReaderScreen()),
    GetPage(
        name: NamedRouter.uploadingFiles,
        page: () => const UploadingFilesScreen()),
    GetPage(name: NamedRouter.account, page: () => const AccountScreen()),
    GetPage(
        name: NamedRouter.downloadManager, page: () => DownloadManagerScreen()),
    GetPage(name: NamedRouter.fileSearch, page: () => FileSearchScreen()),
    GetPage(
        name: NamedRouter.cacheManager, page: () => const CacheManagerScreen()),
    GetPage(
        name: NamedRouter.playerSettings,
        page: () => const PlayerSettingsScreen()),
    GetPage(
        name: NamedRouter.localVideos, page: () => const LocalVideoScreen()),
    GetPage(
        name: NamedRouter.localStorageBrowser,
        page: () => const LocalStorageBrowserScreen()),
    GetPage(name: NamedRouter.smb, page: () => const SmbListScreen()),
    GetPage(name: NamedRouter.smbBrowser, page: () => const SmbBrowserScreen()),
    GetPage(name: NamedRouter.smbScan, page: () => const SmbScanScreen()),
  ];
}
