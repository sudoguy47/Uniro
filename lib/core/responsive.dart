import 'package:flutter/material.dart';

/// Central responsive foundation: breakpoints, screen metrics,
/// design tokens, and layout clearance helpers.
class AppBreakpoints {
  /// Small phones (e.g. 320dp width like iPhone SE 1st gen / small Androids).
  static const double compactMax = 360.0;

  /// Standard to large phones (360dp to 600dp width).
  static const double mediumMax = 600.0;

  /// Max content width for tablets / desktop / foldables to prevent
  /// grotesque stretching.
  static const double maxContentWidth = 600.0;
}

enum ResponsiveBreakpoint {
  compact, // < 360
  medium,  // 360 - 600
  expanded // > 600
}

/// Spacing design tokens (xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32).
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Corner radius design tokens.
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

/// Navigation and safe area insets helpers.
class AppInsets {
  /// Base height of the bottom navigation bar content (excluding safe area padding).
  static const double navBarContentHeight = 68.0;

  /// Default breathing room above the nav bar for scrollable content.
  static const double defaultNavBuffer = 20.0;

  /// Total bottom clearance needed to scroll completely past the nav bar,
  /// including the device bottom safe-area (home indicator / 3-button nav) + extra buffer.
  static double bottomNavClearance(BuildContext context, {double extra = defaultNavBuffer}) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return navBarContentHeight + bottomInset + extra;
  }

  /// Total height of the navigation bar itself (content + bottom safe area).
  static double navBarTotalHeight(BuildContext context) {
    return navBarContentHeight + MediaQuery.paddingOf(context).bottom;
  }
}

/// BuildContext responsive convenience extensions.
///
/// Uses [MediaQuery.sizeOf], [MediaQuery.paddingOf], and [MediaQuery.viewInsetsOf]
/// to avoid unnecessary widget rebuilds when unrelated MediaQuery fields change.
extension ResponsiveContext on BuildContext {
  /// Current screen width.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Current screen height.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Screen size.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Safe area padding (notch, status bar, navigation bar).
  EdgeInsets get screenPadding => MediaQuery.paddingOf(this);

  /// Keyboard and system view insets.
  EdgeInsets get screenViewInsets => MediaQuery.viewInsetsOf(this);

  /// Active responsive breakpoint.
  ResponsiveBreakpoint get breakpoint {
    final w = screenWidth;
    if (w < AppBreakpoints.compactMax) return ResponsiveBreakpoint.compact;
    if (w <= AppBreakpoints.mediumMax) return ResponsiveBreakpoint.medium;
    return ResponsiveBreakpoint.expanded;
  }

  /// True for screens narrower than 360dp.
  bool get isCompact => screenWidth < AppBreakpoints.compactMax;

  /// True for standard phones (360dp to 600dp).
  bool get isMedium =>
      screenWidth >= AppBreakpoints.compactMax &&
      screenWidth <= AppBreakpoints.mediumMax;

  /// True for wide phones, foldables, and tablets (> 600dp).
  bool get isExpanded => screenWidth > AppBreakpoints.mediumMax;

  /// True for tablet form factors.
  bool get isTablet => screenWidth >= AppBreakpoints.mediumMax;
}

/// Centers and constrains child content to [maxWidth] (default 600dp)
/// on tablets, foldables, and desktop displays.
class ResponsiveContentContainer extends StatelessWidget {
  const ResponsiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= maxWidth) {
      return child;
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
