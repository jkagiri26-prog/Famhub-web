// ignore: dangling_library_doc_comments
/// ============================================================
/// ACTIVITY TEMPLATE SELECTION PAGE
/// ============================================================
///
/// Provides a catalog-style selection of agricultural workflows.
/// Users can browse by category (crops, livestock, etc.) and
/// select the appropriate template for their activity.
///
/// This is the entry point for the Dynamic Activity Engine.
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/workflows/dynamic_activity_engine.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/dynamic_activity_execution_page.dart';

class ActivityTemplateSelectionPage extends ConsumerStatefulWidget {
  const ActivityTemplateSelectionPage({super.key});

  @override
  ConsumerState<ActivityTemplateSelectionPage> createState() => _ActivityTemplateSelectionPageState();
}

class _ActivityTemplateSelectionPageState
    extends ConsumerState<ActivityTemplateSelectionPage> {
  String _selectedCategory = 'all';

  static const _categories = [
    ('all', 'All', Icons.explore),
    ('crops', 'Crops', Icons.eco),
    ('livestock', 'Livestock', Icons.pets),
  ];

  @override
  Widget build(BuildContext context) {
    final asyncTemplates = ref.watch(activityTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agricultural Activity Templates'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: asyncTemplates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load templates: $e')),
        data: (templates) => _buildTemplateList(context, templates),
      ),
    );
  }

  Widget _buildTemplateList(BuildContext context, Map<String, ActivityTemplate> templates) {
    // Filter by category
    final filtered = _selectedCategory == 'all'
        ? templates.values.toList()
        : templates.values
            .where((t) => t.category == _selectedCategory)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Category Filter ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.$3, size: 16),
                        const SizedBox(width: 6),
                        Text(cat.$2),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat.$1);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
      ),

        // ── Template List ──
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No templates for this category',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final template = filtered[index];
                    return _TemplateCard(
                      template: template,
                      onTap: () => _startWorkflow(context, template),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _startWorkflow(BuildContext context, ActivityTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DynamicActivityExecutionPage(
          templateId: template.id,
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final ActivityTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _categoryColor(template.category);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _resolveIcon(template.icon),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.description ?? 'No description',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _InfoChip(
                          label: '${template.attributes.length} fields',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          label: '${template.stages.length} stage${template.stages.length == 1 ? '' : 's'}',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _resolveIcon(String? iconName) {
    switch (iconName) {
      case 'eco':
        return Icons.eco;
      case 'water':
        return Icons.water;
      case 'water_drop':
        return Icons.water_drop;
      case 'restaurant':
        return Icons.restaurant;
      case 'set_meal':
        return Icons.set_meal;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.event_note;
    }
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'crops':
        return Colors.green;
      case 'livestock':
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}