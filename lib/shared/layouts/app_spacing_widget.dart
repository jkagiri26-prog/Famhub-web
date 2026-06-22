/// ============================================================
/// APP SPACING WIDGET (REUSABLE SPACING CONSTANTS)
/// ============================================================
///
/// ?? LOCATION CONTEXT:
///   shared/layouts/ = reusable layout primitives
///
/// ? Responsibilities:
///   - Provide consistent spacing values
///   - Standardized gap sizes across the app
///
/// ? Does NOT:
///   - Reference registries or providers
///   - Contain business logic
/// ============================================================
library;

import 'package:flutter/material.dart';

class AppSpacingWidget extends StatelessWidget {
  final double height;
  final double width;

  const AppSpacingWidget({
    super.key,
    this.height = 0,
    this.width = 0,
  });

  /// Standard small spacing (8px)
  static const AppSpacingWidget small = AppSpacingWidget(height: 8);

  /// Standard medium spacing (16px)
  static const AppSpacingWidget medium = AppSpacingWidget(height: 16);

  /// Standard large spacing (24px)
  static const AppSpacingWidget large = AppSpacingWidget(height: 24);

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: width);
  }
}
