import 'package:flutter/material.dart';

/// Wrapper widget that adds accessibility features to any widget
class AccessibilityWrapper extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final String? semanticHint;
  final bool? isButton;
  final bool? isHeader;
  final bool? excludeSemantics;

  const AccessibilityWrapper({
    super.key,
    required this.child,
    this.semanticLabel,
    this.semanticHint,
    this.isButton,
    this.isHeader,
    this.excludeSemantics,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: isButton ?? false,
      header: isHeader ?? false,
      excludeSemantics: excludeSemantics ?? false,
      child: child,
    );
  }
}

/// Helper extension to add accessibility to widgets easily
extension AccessibilityExtension on Widget {
  Widget withAccessibility({
    String? label,
    String? hint,
    bool? isButton,
    bool? isHeader,
  }) {
    return AccessibilityWrapper(
      semanticLabel: label,
      semanticHint: hint,
      isButton: isButton,
      isHeader: isHeader,
      child: this,
    );
  }
}

