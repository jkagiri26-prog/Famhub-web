/// ============================================================
/// FEATURE PAGE SCAFFOLD (REUSABLE MODULE PAGE SHELL)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/layouts/ = reusable layout primitives
///
/// ✅ Responsibilities:
///   - Consistent module page structure
///   - Header + content + optional trailing action
///   - Responsive by default
///
/// ❌ Does NOT:
///   - Reference registry, services, or providers
///   - Contain business logic
///   - Import Supabase
/// ============================================================

import 'package:flutter/material.dart';

class FeaturePageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final bool isLoading;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  const FeaturePageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.children,
    this.isLoading = false,
    this.scrollable = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (isLoading) {
      return _buildLoading(context);
    }

    if (scrollable) {
      return Padding(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ...children,
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 200,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 280,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
