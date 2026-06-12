import 'package:flutter/material.dart';


/// FAMHUB Shared Layout
///
/// Standard responsive wrapper for all module pages.
///
/// Rules:
/// - No Scaffold
/// - No AppBar
/// - No Drawer
/// - No BottomNavigationBar
/// - Used inside MainShell / DashboardShell only
/// - Mobile-first layout
/// - Tablet/Desktop adaptive constraints
///
/// This ensures consistent width handling across the platform.

class ResponsiveWrapperWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: backgroundColor ?? const Color(0xFFF8F9FA),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double maxWidth;

            if (constraints.maxWidth < 600) {
              /// Mobile
              maxWidth = double.infinity;
            } else if (constraints.maxWidth < 1024) {
              /// Tablet
              maxWidth = 900;
            } else {
              /// Desktop
              maxWidth = 1200;
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
              ),
              child: Padding(
                padding:
                    padding ??
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}