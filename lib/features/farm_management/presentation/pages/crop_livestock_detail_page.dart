import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/activity_creation_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/production_page.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/stock_selection_page.dart';

/// Detail workspace for one crop or livestock asset.
///
/// The selected record remains the hierarchy context while the user opens
/// activity, production, or managed-stock screens.
class CropLivestockDetailPage extends ConsumerStatefulWidget {
  final CropEntity? crop;
  final LivestockEntity? livestock;

  const CropLivestockDetailPage.crop({
    super.key,
    required CropEntity crop,
  })  : crop = crop,
        livestock = null;

  const CropLivestockDetailPage.livestock({
    super.key,
    required LivestockEntity livestock,
  })  : crop = null,
        livestock = livestock;

  bool get isCrop => crop != null;
  String get title => isCrop ? crop!.cropName : livestock!.species;
  String get searchQuery => isCrop ? crop!.cropName : livestock!.species;

  @override
  ConsumerState<CropLivestockDetailPage> createState() =>
      _CropLivestockDetailPageState();
}

class _CropLivestockDetailPageState
    extends ConsumerState<CropLivestockDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_selectAsset);
  }

  void _selectAsset() {
    final notifier = ref.read(hierarchyProvider.notifier);
    if (widget.isCrop) {
      notifier.selectCrop(widget.crop!);
    } else {
      notifier.selectLivestock(widget.livestock!);
    }
  }

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = ref.watch(hierarchyProvider);
    final fieldName = hierarchy.field?.fieldName ?? 'Selected field';
    final isCrop = widget.isCrop;

    return ShellPageContent(
      title: widget.title,
      subtitle: '${isCrop ? 'Crop' : 'Livestock'} in $fieldName',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(isCrop ? Icons.eco : Icons.pets),
                title: Text(widget.title),
                subtitle: Text(
                  isCrop
                      ? (widget.crop!.variety ?? 'Crop')
                      : '${widget.livestock!.breed ?? 'Livestock'} · ${widget.livestock!.count ?? 0} head',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Manage this ${isCrop ? 'crop' : 'livestock asset'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.event_note,
              label: 'Record Activity',
              onPressed: () => _open(const ActivityCreationPage()),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.shopping_basket,
              label: 'Sell on Marketplace',
              onPressed: () => _open(
                StockSelectionPage(initialSearchQuery: widget.searchQuery),
              ),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.factory_outlined,
              label: 'Record Production',
              onPressed: () => _open(const ProductionRecordingPage()),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.inventory_2_outlined,
              label: 'View Stock',
              onPressed: () => _open(
                StockSelectionPage(initialSearchQuery: widget.searchQuery),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
