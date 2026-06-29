import 'package:flutter/material.dart';

/// Custom ScrollBehavior that disables overscroll effects
/// This removes the bounce/glow effect when scrolling beyond content limits
class NoOverscrollBehavior extends ScrollBehavior {
  /// Removes the overscroll indicator (glow effect)
  /// Returns the child widget without any overscroll visual effects
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // Return child without overscroll indicator
  }

  /// Uses ClampingScrollPhysics to prevent overscroll bouncing
  /// This stops the content from stretching beyond its boundaries
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(); // Prevents bounce effect
  }

  // Note: buildViewportChrome method has been removed as it's no longer part of
  // the ScrollBehavior class in newer Flutter versions. The overscroll behavior
  // is already handled by buildOverscrollIndicator and getScrollPhysics.
}
