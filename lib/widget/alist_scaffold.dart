import 'package:list_linker/util/widget_utils.dart';
import 'package:flutter/material.dart';

class AlistScaffold extends StatelessWidget {
  const AlistScaffold({
    Key? key,
    this.appbarTitle,
    required this.body,
    this.onLeadingDoubleTap,
    this.resizeToAvoidBottomInset,
    this.appbarActions,
    this.appbarLeading,
    this.showAppbar = true,
  }) : super(key: key);
  final Widget? appbarTitle;
  final Widget body;
  final GestureTapCallback? onLeadingDoubleTap;
  final bool? resizeToAvoidBottomInset;
  final List<Widget>? appbarActions;
  final Widget? appbarLeading;
  final bool showAppbar;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = WidgetUtils.isDarkMode(context);
    final platform = Theme.of(context).platform;
    final isDesktop = platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final scheme = Theme.of(context).colorScheme;

    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final canPop = parentRoute != null && parentRoute.canPop;

    return DecoratedBox(
        decoration: !isDarkMode && !isDesktop
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.surface],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : BoxDecoration(color: scheme.surface),
        child: Scaffold(
          backgroundColor: scheme.surface,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
          appBar: !showAppbar
              ? null
              : AppBar(
                  leading: appbarLeading ??
                      (canPop
                          ? GestureDetector(
                              onDoubleTap: onLeadingDoubleTap,
                              child: const BackButton(),
                            )
                          : null),
                  automaticallyImplyLeading: false,
                  backgroundColor: scheme.surface,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  elevation: 0,
                  titleSpacing: canPop ? 0 : 20,
                  title: appbarTitle,
                  actions: appbarActions,
                ),
          // Keep top/side safe insets; leave bottom free so scrollables can
          // use MediaQuery.viewPadding.bottom as list end padding instead of
          // shrinking the viewport (system nav bar coverage fix).
          body: SafeArea(bottom: false, child: body),
        ));
  }
}
