/// ============================================================
/// AGRI CONNECT — FORUM TAB
/// ============================================================
///
/// Full public discussion browser: search, type/sort filters and
/// discussion creation. Uses the same discussion list as Home.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/community_provider.dart';
import '../../application/providers/discussion_provider.dart';
import '../../domain/entities/discussion.dart';
import '../../domain/enums/discussion_enums.dart';
import '../format.dart';
import '../widgets/agri_feed_card_placeholder_widget.dart';
import '../widgets/discussion_card.dart';
import 'create_discussion_page.dart';
import 'discussion_details_page.dart';

class ForumTab extends ConsumerStatefulWidget {
  const ForumTab({super.key});

  @override
  ConsumerState<ForumTab> createState() => _ForumTabState();
}

class _ForumTabState extends ConsumerState<ForumTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  DiscussionType? _type;
  bool _openOnly = false;
  bool _newestFirst = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _type = null;
      _openOnly = false;
      _newestFirst = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final discussionsAsync = ref.watch(discussionsProvider(null));
    final authors =
        ref.watch(discussionAuthorNamesProvider(null)).value ??
        const <String, String>{};
    final communityNames = ref.watch(communityNamesProvider);

    final discussions = discussionsAsync.value ?? const <Discussion>[];
    final filtered = _applyFilters(discussions);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search discussions…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clearFilters,
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Agricultural discussions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _startDiscussion,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Start'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _typeChip(null, 'All'),
              for (final t in DiscussionType.values) _typeChip(t, t.label),
              const SizedBox(width: 8),
              _sortChip(newest: true, label: 'Newest'),
              _sortChip(newest: false, label: 'Most replies'),
              const SizedBox(width: 8),
              FilterChip(
                selected: _openOnly,
                onSelected: (v) => setState(() => _openOnly = v),
                showCheckmark: false,
                avatar: Icon(
                  Icons.lock_open_outlined,
                  size: 15,
                  color: _openOnly ? cs.primary : cs.outline,
                ),
                label: const Text('Open only'),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _openOnly ? cs.primary : cs.onSurfaceVariant,
                ),
                backgroundColor: Colors.white,
                selectedColor: cs.primary.withValues(alpha: 0.10),
                side: BorderSide(
                  color: _openOnly ? cs.primary : cs.outlineVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _buildList(
            context,
            discussionsAsync,
            filtered,
            authors,
            communityNames,
          ),
        ),
      ],
    );
  }

  // ── Filters ────────────────────────────────────────────────

  List<Discussion> _applyFilters(List<Discussion> discussions) {
    var list = discussions;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) => d.title.toLowerCase().contains(q)).toList();
    }
    if (_type != null) {
      list = list.where((d) => d.type == _type).toList();
    }
    if (_openOnly) {
      list = list.where((d) => !d.isLocked).toList();
    }
    if (!_newestFirst) {
      list = [...list]..sort((a, b) => b.replyCount.compareTo(a.replyCount));
    }
    return list;
  }

  Widget _typeChip(DiscussionType? type, String label) {
    final cs = Theme.of(context).colorScheme;
    final selected = _type == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _type = type),
        selectedColor: cs.primary.withValues(alpha: 0.10),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        ),
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      ),
    );
  }

  Widget _sortChip({required bool newest, required String label}) {
    final cs = Theme.of(context).colorScheme;
    final selected = _newestFirst == newest;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _newestFirst = newest),
        selectedColor: cs.tertiary.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? cs.tertiary : cs.onSurfaceVariant,
        ),
        side: BorderSide(color: selected ? cs.tertiary : cs.outlineVariant),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────

  Widget _buildList(
    BuildContext context,
    AsyncValue<List<Discussion>> async,
    List<Discussion> filtered,
    Map<String, String> authors,
    Map<String, String> communityNames,
  ) {
    return async.when(
      loading: () => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: const [
          AgriFeedCardPlaceholderWidget(title: 'Discussion', subtitle: ''),
          AgriFeedCardPlaceholderWidget(title: 'Discussion', subtitle: ''),
          AgriFeedCardPlaceholderWidget(title: 'Discussion', subtitle: ''),
          AgriFeedCardPlaceholderWidget(title: 'Discussion', subtitle: ''),
        ],
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load discussions.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(discussionsProvider(null)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (_) {
        if (filtered.isEmpty) {
          final noDiscussionsAtAll =
              (async.value ?? const <Discussion>[]).isEmpty;
          return noDiscussionsAtAll
              ? _emptyForum(context)
              : _noMatches(context);
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final d = filtered[index];
            return DiscussionCard(
              discussion: d,
              authorName: authors[d.createdBy],
              communityName: d.communityId == null
                  ? null
                  : communityNames[d.communityId],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DiscussionDetailsPage(discussionId: d.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyForum(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 44, color: cs.tertiary),
            const SizedBox(height: 12),
            const Text(
              'No discussions yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to start an agricultural conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _startDiscussion,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Start a discussion'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noMatches(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: cs.outline),
            const SizedBox(height: 12),
            const Text(
              'No discussions match your search.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _startDiscussion() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateDiscussionPage()));
  }
}
