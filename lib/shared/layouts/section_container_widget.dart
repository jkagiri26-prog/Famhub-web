import 'package:flutter/material.dart';

/// FAMHUB Shared Layout
///
/// Standard white content container used across:
/// - analytics cards
/// - dashboard cards
/// - reports
/// - forms
/// - grouped sections
///
/// This ensures:
/// UI consistency
/// spacing consistency
/// border consistency
/// production-safe design

class SectionContainerWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const SectionContainerWidget({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: double.infinity,
      margin:
          margin ??
          const EdgeInsets.only(
            bottom: 12,
          ),
      padding:
          padding ??
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: container,
      );
    }

    return container;
  }
}