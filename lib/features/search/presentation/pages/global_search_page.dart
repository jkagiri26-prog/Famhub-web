/// ============================================================
/// UNIFIED SEARCH PAGE (ENTERPRISE PHASE 4)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/search/presentation/pages/ = global search layer
///
/// ✅ Responsibilities:
///   - Global search aggregating across all search providers
///   - Search providers come from SearchProviderDescriptor
///   - No module-specific search code
///   - Supports: Marketplace, Farms, Livestock, Inventory,
///     Knowledge, Financing, Documents, AI, Reports, Users
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Search providers registered by each module
///   - Engine aggregates from all enabled modules
///   - No hardcoded search sources
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/contribution_registry.dart';
import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// GLOBAL SEARCH PROVIDER
/// ============================================================
final globalSearchProvidersProvider = FutureProvider<List<SearchProviderDescriptor>>((ref) async {
  return ref.watch(searchProviderDescriptorsProvider.future);
});

/// ============================================================
/// GLOBAL SEARCH PAGE
/// ============================================================
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providersAsync = ref.watch(globalSearchProvidersProvider);

    return ShellPageContent(
      title: 'Search',
      padding: EdgeInsets.zero,
      scrollable: false,
      child: Column(
        children: [
          // ── Search text field ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search across all modules...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.black87,
              ),
            ),
          ),
          // ── Search content ──
          Expanded(
            child: _query.isEmpty
                ? _buildInitialState(theme, providersAsync)
                : _buildSearchResults(theme, providersAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(
    ThemeData theme,
    AsyncValue<List<SearchProviderDescriptor>> providersAsync,
  ) {
    return providersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (providers) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search across ${providers.length} sources',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final provider = providers[index];
                    return _SearchProviderCard(
                      provider: provider,
                      onTap: () {
                        _searchController.text = provider.displayName;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(
    ThemeData theme,
    AsyncValue<List<SearchProviderDescriptor>> providersAsync,
  ) {
    return providersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (providers) {
        // Filter providers by query match
        final query = _query.toLowerCase();
        final matchingProviders = providers.where((p) =>
          p.displayName.toLowerCase().contains(query) ||
          p.entityTypes.any((e) => e.toLowerCase().contains(query))
        ).toList();

        if (matchingProviders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matchingProviders.length,
          itemBuilder: (context, index) {
            final provider = matchingProviders[index];
            return _SearchResultTile(
              provider: provider,
              query: _query,
            );
          },
        );
      },
    );
  }
}

/// ============================================================
/// SEARCH PROVIDER CARD
/// ============================================================
class _SearchProviderCard extends StatelessWidget {
  final SearchProviderDescriptor provider;
  final VoidCallback onTap;

  const _SearchProviderCard({
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = IconResolver.resolve(provider.providerKey);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
    
  }
}

/// ============================================================
/// SEARCH RESULT TILE
/// ============================================================
class _SearchResultTile extends StatelessWidget {
  final SearchProviderDescriptor provider;
  final String query;

  const _SearchResultTile({
    required this.provider,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = IconResolver.resolve(provider.providerKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  provider.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Search "${provider.displayName}" for "$query"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: provider.entityTypes.map((type) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
