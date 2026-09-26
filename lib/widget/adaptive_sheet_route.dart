import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

extension AdaptiveSheetRouteX on Widget {
  Route<T> asAdaptiveSheetRoute<T>() {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (isIos) {
      return StupidSimpleGlassSheetRoute<T>(
        child: this,
        blurBehindBarrier: false,
      );
    }
    return StupidSimpleSheetRoute<T>(child: this);
  }
}
