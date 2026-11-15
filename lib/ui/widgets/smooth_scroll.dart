import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom ScrollPosition that intercepts mouse wheel pointer scroll events
/// and animates them smoothly with easeOutCubic curve instead of abrupt jumps.
class SmoothScrollPositionWithSingleContext extends ScrollPositionWithSingleContext {
  SmoothScrollPositionWithSingleContext({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  double _futurePixels = 0.0;

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      goBallistic(0.0);
      return;
    }

    // Reset target if user dragged scrollbar or jumped far away
    if ((pixels - _futurePixels).abs() > 400 ||
        _futurePixels < minScrollExtent ||
        _futurePixels > maxScrollExtent) {
      _futurePixels = pixels;
    }

    _futurePixels += delta;
    final double targetPixels = math.min(
      math.max(_futurePixels, minScrollExtent),
      maxScrollExtent,
    );
    _futurePixels = targetPixels;

    if (targetPixels != pixels) {
      animateTo(
        targetPixels,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

/// A ScrollController that creates [SmoothScrollPositionWithSingleContext]
/// for butter-smooth desktop scrolling on mouse wheel movements.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SmoothScrollPositionWithSingleContext(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}
