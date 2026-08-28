import 'package:list_linker/generated/images.dart';
import 'package:list_linker/util/widget_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared layout tokens + primitives aligned with ListLinker + Flutter Pro taste.
class AppUi {
  static const double pagePadding = 16;
  static const double sectionGap = 20;
  static const double itemGap = 12;
  static const double radius = 14;
  static const double iconBox = 44;

  static EdgeInsets pageInsets(BuildContext context, {double top = 8}) {
    return EdgeInsets.fromLTRB(
      pagePadding,
      top,
      pagePadding,
      16 + WidgetUtils.listBottomInset(context),
    );
  }

  static Color tileBg(BuildContext context) {
    return Theme.of(context).colorScheme.surface.withOpacity(
          WidgetUtils.isDarkMode(context) ? 0.35 : 0.55,
        );
  }

  static Color muted(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  static InputDecoration fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: scheme.surfaceVariant.withOpacity(0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: true,
    );
  }
}

/// Soft icon badge used in empty states and list leadings.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.size = 56,
    this.iconSize = 28,
    this.color,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.85),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

/// Calm empty / error state: icon → title → body → actions.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.primaryAction,
    this.secondaryAction,
    this.tertiaryAction,
    this.expand = true,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final Widget? tertiaryAction;

  /// When true, fills available space and centers content.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconBadge(icon: icon, size: 72, iconSize: 34),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (body != null && body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppUi.muted(context),
                height: 1.45,
              ),
            ),
          ],
          if (primaryAction != null) ...[
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: primaryAction),
          ],
          if (secondaryAction != null) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: secondaryAction),
          ],
          if (tertiaryAction != null) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: tertiaryAction),
          ],
        ],
      ),
    );

    if (!expand) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: content,
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: content,
      ),
    );
  }
}

/// Settings-style row: soft leading, quiet subtitle, optional trailing.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final isDark = WidgetUtils.isDarkMode(context);
    final scheme = Theme.of(context).colorScheme;

    Widget? lead = leading;
    if (lead == null && leadingIcon != null) {
      lead = AppIconBadge(
        icon: leadingIcon!,
        size: AppUi.iconBox,
        iconSize: 22,
      );
    }

    Widget? trail = trailing;
    if (trail == null && showChevron) {
      trail = Image.asset(
        Images.iconArrowRight,
        color: isDark ? Colors.white : null,
        width: 18,
        height: 18,
      );
    }

    return Material(
      color: AppUi.tileBg(context),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (lead != null) ...[
                lead,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trail != null) ...[
                const SizedBox(width: 8),
                trail,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact action card (icon + label + optional caption).
class AppActionCard extends StatelessWidget {
  const AppActionCard({
    super.key,
    required this.icon,
    required this.label,
    this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withOpacity(
        WidgetUtils.isDarkMode(context) ? 0.4 : 0.72,
      ),
      borderRadius: BorderRadius.circular(AppUi.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(icon: icon, size: 40, iconSize: 20),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Section title used above card grids / lists.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppUi.muted(context),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

/// Bottom sheet chrome: handle + padded column.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required List<Widget> children,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
    },
  );
}

/// Form field stack with consistent vertical rhythm.
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        decoration: AppUi.fieldDecoration(
          context,
          label: label,
          hint: hint,
        ),
      ),
    );
  }
}

/// Thin inset divider matching file list separators.
class AppInsetDivider extends StatelessWidget {
  const AppInsetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 0.6),
    );
  }
}
