import 'dashboard_descriptor.dart';
import 'dashboard_block.dart';

/// ============================================================
/// DASHBOARD LAYOUT RESPONSE (PRE-RENDER CONTRACT)
/// ============================================================
///
/// This is NOT a UI model.
///
/// It is used ONLY as a transport layer between:
/// - repository
/// - layout compiler
/// - renderer pipeline
///
/// Blocks = structure layer
/// Descriptors = render layer
/// ============================================================

class DashboardLayoutResponse {
  final List<DashboardDescriptor> descriptors;
  final List<DashboardBlock> blocks;

  const DashboardLayoutResponse({
    required this.descriptors,
    required this.blocks,
  });

  /// Empty safe state
  factory DashboardLayoutResponse.empty() {
    return const DashboardLayoutResponse(
      descriptors: [],
      blocks: [],
    );
  }

  /// True if there is anything to process
  bool get hasData => descriptors.isNotEmpty || blocks.isNotEmpty;

  /// ⚡ Derived helpers (future pipeline optimization)
  bool get hasRenderableDescriptors => descriptors.isNotEmpty;
  bool get hasLayoutBlocks => blocks.isNotEmpty;
}