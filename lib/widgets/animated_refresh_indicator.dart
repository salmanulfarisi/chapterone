import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

/// Enhanced pull-to-refresh indicator with custom animations
class AnimatedRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double displacement;

  const AnimatedRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.displacement = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Haptic feedback on refresh
        HapticFeedback.mediumImpact();
        await onRefresh();
      },
      color: color ?? AppTheme.primaryRed,
      backgroundColor: backgroundColor ?? AppTheme.cardBackground,
      displacement: displacement,
      strokeWidth: 3.0,
      child: child,
    );
  }
}

/// Custom refresh indicator with animation
class CustomRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;

  const CustomRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
  });

  @override
  State<CustomRefreshIndicator> createState() => _CustomRefreshIndicatorState();
}

class _CustomRefreshIndicatorState extends State<CustomRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    _controller.forward();
    await widget.onRefresh();
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: widget.color ?? AppTheme.primaryRed,
      backgroundColor: AppTheme.cardBackground,
      strokeWidth: 3.0,
      child: widget.child,
    );
  }
}

