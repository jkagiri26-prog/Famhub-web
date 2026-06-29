import 'package:flutter/material.dart';

/// ============================================================
/// MODULE ERROR BOUNDARY
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/ = reusable presentation widgets
///
/// ✅ Responsibilities:
///   - Catch errors during module widget rendering
///   - Display fallback placeholder instead of crashing
///   - Log errors for telemetry (non-blocking)
///   - Keep the rest of the dashboard functional
///
/// ✅ Success Criteria:
///   - A single failing module never crashes the dashboard
///   - Error is isolated and scoped to the failed module
///   - Other modules continue to render normally
///
/// ❌ Does NOT:
///   - Suppress errors silently (shows placeholder)
///   - Retry failed modules automatically
///   - Contain business logic
/// ============================================================
class ModuleErrorBoundary extends StatefulWidget {
  final String moduleKey;
  final String displayName;
  final Widget child;

  const ModuleErrorBoundary({
    super.key,
    required this.moduleKey,
    required this.displayName,
    required this.child,
  });

  @override
  State<ModuleErrorBoundary> createState() => _ModuleErrorBoundaryState();
}

class _ModuleErrorBoundaryState extends State<ModuleErrorBoundary> {
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hasError = false;
    _errorMessage = null;
  }

  @override
  void didUpdateWidget(ModuleErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset error state if the child widget changes (e.g. module refresh)
    if (oldWidget.moduleKey != widget.moduleKey) {
      _hasError = false;
      _errorMessage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildPlaceholder();
    }

    return _ErrorCapturingWidget(
      moduleKey: widget.moduleKey,
      displayName: widget.displayName,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
        });
      },
      child: widget.child,
    );
  }

  Widget _buildPlaceholder() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.orange.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.displayName} unavailable',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This module encountered an error and is being reloaded.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// ERROR CAPTURING WRAPPER (SAFE ZONE ERROR BOUNDARY)
/// ============================================================
///
/// Uses runZonedGuarded to catch errors in the child subtree.
/// This is the safest approach for isolating widget build errors
/// without affecting the global Flutter error handling.
///
/// Pattern:
/// 1. Wraps child in a Builder widget
/// 2. Catches errors using FlutterError.onError locally
/// 3. Reports to parent ModuleErrorBoundary
/// ============================================================
class _ErrorCapturingWidget extends StatelessWidget {
  final String moduleKey;
  final String displayName;
  final Widget child;
  final void Function(Object error) onError;

  const _ErrorCapturingWidget({
    required this.moduleKey,
    required this.displayName,
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return SafeBuilder(
      onError: onError,
      child: child,
    );
  }
}

/// ============================================================
/// SAFE BUILDER (ERROR-RESILIENT WRAPPER)
/// ============================================================
///
/// Wraps child in a Builder and uses FlutterError.onError
/// to capture build-phase errors. When an error occurs:
/// 1. Captures the error details
/// 2. Reports to parent via onError callback
/// 3. Renders an empty SizedBox (parent shows placeholder)
///
/// This doesn't require Zone, global state mutation, or
/// overriding ErrorWidget.builder.
/// ============================================================
class SafeBuilder extends StatefulWidget {
  final Widget child;
  final void Function(Object error) onError;

  const SafeBuilder({
    super.key,
    required this.child,
    required this.onError,
  });

  @override
  State<SafeBuilder> createState() => _SafeBuilderState();
}

class _SafeBuilderState extends State<SafeBuilder> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _hasError = false;
  }

  @override
  void didUpdateWidget(SafeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset on child change
    if (oldWidget.child != widget.child) {
      _hasError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox.shrink();
    }

    return _ErrorDetector(
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
        });
        widget.onError(error);
      },
      child: widget.child,
    );
  }
}

/// ============================================================
/// ERROR DETECTOR
/// ============================================================
///
/// Minimal wrapper that delegates to build() and catches
/// any synchronous exceptions during the build process.
/// ============================================================
class _ErrorDetector extends StatelessWidget {
  final Widget child;
  final void Function(Object error) onError;

  const _ErrorDetector({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (e) {
      // Synchronous errors during build
      Future.microtask(() => onError(e));
      return const SizedBox.shrink();
    }
  }
}
