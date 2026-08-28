import 'dart:io';

import 'package:flustars/flustars.dart';
import 'package:list_linker/util/constant.dart';

void configureAppHttpOverrides() {
  _ignoreSSLErrors =
      SpUtil.getBool(AlistConstant.ignoreSSLError) == true;
  HttpOverrides.global = _AppHttpOverrides();
}

bool _ignoreSSLErrors = false;

void setAppIgnoreSSLErrors(bool ignore) {
  _ignoreSSLErrors = ignore;
}

class _AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (certificate, host, port) => _ignoreSSLErrors;
    return client;
  }
}
