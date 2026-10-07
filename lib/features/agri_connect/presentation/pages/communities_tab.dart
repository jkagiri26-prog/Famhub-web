/// ============================================================
/// AGRI CONNECT — COMMUNITIES TAB
/// ============================================================
///
/// My Communities, Discover Communities and Create Community.
/// Opening a community leads to the existing community detail shell.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/community_provider.dart';
import '../widgets/community_card.dart';
import 'community_details_page.dart';
import 'create_community_page.dart';

class CommunitiesTab extends ConsumerStatefulWidget {
  const CommunitiesTab({super.key});

  @override
  ConsumerState<CommunitiesTab> createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends ConsumerState<CommunitiesTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  void _createCommunity() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateCommunityPage()));
  }

  void _openCommunity(String communityId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityDetailsPage(communityId: communityId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoverAsync = ref.watch(
      discoverCommunitiesProvider((query: _searchQuery, type: null)),
    );
    final myCommunitiesAsync = ref.watch(myCommunitiesProvider);
    final myIds = (myCommunitiesAsync.value ?? const [])
        .map((c) => c.id)
        .toSet();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search communities…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: discoverAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load communities.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(
                      discoverCommunitiesProvider((
                        query: _searchQuery,
                        type: null,
                      )),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (communities) {
              if (communities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        size: 40,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      const Text('No communities yet.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _createCommunity,
                        icon: const Icon(Icons.add),
                        label: const Text('Create a community'),
                      ),
                    ],
                  ),
                );
              }

              final myComms = communities
                  .where((c) => myIds.contains(c.id))
                  .toList();
              final discover = communities
                  .where((c) => !myIds.contains(c.id))
                  .toList();

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  if (myComms.isNotEmpty) ...[
                    _sectionHeader(
                      'My communities',
                      actionLabel: 'Create',
                      onAction: _createCommunity,
                    ),
                    const SizedBox(height: 8),
                    for (final c in myComms)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CommunityCard(
                          community: c,
                          isMember: true,
                          onTap: () => _openCommunity(c.id),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  _sectionHeader(
                    discover.isEmpty ? '' : 'Discover communities',
                    actionLabel: myComms.isEmpty ? 'Create' : null,
                    onAction: myComms.isEmpty ? _createCommunity : null,
                  ),
                  if (discover.isEmpty && myComms.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'You are a member of all visible communities.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                  for (final c in discover)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CommunityCard(
                        community: c,
                        onTap: () => _openCommunity(c.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (title.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: cs.onSurface,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
