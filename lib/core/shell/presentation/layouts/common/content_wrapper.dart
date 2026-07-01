/// ============================================================
/// CONTENT WRAPPER
/// ============================================================
///
/// Wraps content with optional max-width constraint and padding.
/// Shared across all shell layouts.
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../../config/shell_config.dart';

/// ============================================================
/// CONTENT WRAPPER
/// ============================================================
class ContentWrapper extends StatelessWidget {
  final Widget child;
  final ContentConfig config;

  const ContentWrapper({
    super.key,
    required this.child,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (config.addContentPadding) {
      content = Padding(
        padding: EdgeInsets.all(config.contentPadding),
        child: content,
      );
    }

    if (config.maxContentWidth != null) {
      content = Center(
        child: SizedBox(
          width: config.maxContentWidth,
          child: content,
        ),
      );
    }

    return content;
  }
}

