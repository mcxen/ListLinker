import 'dart:io';

import 'package:list_linker/util/global.dart';

class MarkdownUtil {
  static makePreviewUrl(String url) {
    String scheme;
    if (Platform.isIOS && url.startsWith("http://")) {
      scheme = "http";
    } else {
      scheme = "https";
    }

    return "$scheme://${Global.configServerHost}/listlinker_h5/showMarkDown?markdownUrl=${Uri.encodeComponent(url)}";
  }
}
