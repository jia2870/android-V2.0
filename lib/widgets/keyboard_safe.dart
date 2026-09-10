import 'package:flutter/material.dart';

/// Shared overflow-safe layout helpers.
/// Guided by ui-ux-pro-max Flutter stack rules:
/// LayoutBuilder for constraints, scroll instead of clip, Expanded/Flexible in flex.
class KeyboardSafeBody extends StatelessWidget {
  const KeyboardSafeBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.centerWhenShort = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool centerWhenShort;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolved = padding.resolve(Directionality.of(context));
          final minHeight =
              (constraints.maxHeight - resolved.vertical).clamp(0.0, double.infinity);

          Widget content = child;
          if (centerWhenShort) {
            content = ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: IntrinsicHeight(child: child),
            );
          }

          return SingleChildScrollView(
            padding: padding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: content,
          );
        },
      ),
    );
  }
}

/// Dialog that stays a stable size when the keyboard opens.
///
/// [overlayKeyboard] (default true): keyboard covers the dialog instead of
/// shrinking it. Callers should add keyboard-height padding inside a
/// scroll view so the focused field can scroll above the keys.
class KeyboardSafeDialog extends StatelessWidget {
  const KeyboardSafeDialog({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.horizontalInset = 16,
    this.verticalInset = 16,
    this.overlayKeyboard = true,
    this.fitContent = false,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalInset;
  final double verticalInset;
  final bool overlayKeyboard;
  /// When true, the dialog is only as tall as [child], up to [maxHeight].
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = overlayKeyboard ? 0.0 : media.viewInsets.bottom;
    final safeVertical = media.padding.top + media.padding.bottom;
    final available = (media.size.height - safeVertical - verticalInset * 2)
        .clamp(120.0, media.size.height);
    final ratio = media.orientation == Orientation.landscape ? 0.94 : 0.9;
    final maxHeight = (available * ratio).clamp(120.0, available);

    final dialog = Dialog(
      insetPadding: EdgeInsets.fromLTRB(
        horizontalInset,
        verticalInset,
        horizontalInset,
        verticalInset + keyboard,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: fitContent
            ? Align(
                alignment: Alignment.center,
                heightFactor: 1,
                child: SizedBox(
                  width: double.infinity,
                  child: child,
                ),
              )
            : SizedBox(
                height: maxHeight,
                width: double.infinity,
                child: child,
              ),
      ),
    );

    if (!overlayKeyboard) return dialog;

    // Stop Dialog's built-in viewInsets padding from squeezing the sheet.
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: dialog,
    );
  }
}

/// Centers content when there is room; scrolls when the viewport is short
/// (keyboard / landscape) so empty states cannot overflow.
class OverflowSafeFill extends StatelessWidget {
  const OverflowSafeFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom composer (chat / search input) that stays above the keyboard.
class KeyboardSafeBottomBar extends StatelessWidget {
  const KeyboardSafeBottomBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      elevation: 0,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: padding.copyWith(
          bottom: padding.bottom + (bottomPad > 0 ? 0 : 0),
        ),
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }
}
