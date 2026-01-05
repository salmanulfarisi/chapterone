import 'package:flutter/material.dart';

/// Enhanced scroll controller with smooth animations
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  /// Smooth scroll to a specific position
  Future<void> smoothScrollTo(
    double offset, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    if (!hasClients) return;
    await animateTo(
      offset,
      duration: duration,
      curve: curve,
    );
  }

  /// Smooth scroll to top
  Future<void> smoothScrollToTop({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    await smoothScrollTo(0, duration: duration, curve: curve);
  }

  /// Smooth scroll to bottom
  Future<void> smoothScrollToBottom({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    if (!hasClients) return;
    await smoothScrollTo(
      position.maxScrollExtent,
      duration: duration,
      curve: curve,
    );
  }

  /// Smooth scroll by a delta
  Future<void> smoothScrollBy(
    double delta, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    if (!hasClients) return;
    await smoothScrollTo(
      position.pixels + delta,
      duration: duration,
      curve: curve,
    );
  }
}

/// Scroll physics with smooth animations
class SmoothScrollPhysics extends ClampingScrollPhysics {
  const SmoothScrollPhysics({super.parent});

  @override
  SmoothScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Use a more gradual deceleration for smoother scrolling
    final tolerance = this.tolerance;
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    return null;
  }
}

/// Widget that provides smooth scrolling behavior
class SmoothScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  const SmoothScrollView({
    super.key,
    required this.child,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      physics: physics ?? const SmoothScrollPhysics(),
      padding: padding,
      child: child,
    );
  }
}

