/// ============================================================
/// AGRI CONNECT — MODULE ENTRY PAGE
/// ============================================================
///
/// Hub for Communities (discover / my communities / create) and
/// Messages (conversations). Centered on:
///   Person → Farm/Business → Community → Discussion/Chat → FAMHUB modules
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';

import '../../application/providers/community_provider.dart';
import '../../application/providers/messaging_provider.dart';
import '../widgets/agri_connect_tab_selector_widget.dart';
import '../widgets/community_card.dart';
import '../widgets/conversation_tile.dart';
import 'community_details_page.dart';
import 'create_community_page.dart';
import 'conversation_page.dart';
import 'new_conversation_page.dart';

class AgriConnectPage extends ConsumerStatefulWidget {
  const AgriConnectPage({super.key});

  @override
  ConsumerState<AgriConnectPage> createState() => _AgriConnectPageState();
}

class _AgriConnectPageState extends ConsumerState<AgriConnectPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _activeTab = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ModuleHeaderWidget(
            title: 'AgriConnect',
            subtitle: 'Communities • Discussions • Farmer Network',
            trailingIcon: Icons.add_circle_outline,
            onTrailingTap: _activeTab == 0
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateCommunityPage(),
                    ),
                  )
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NewConversationPage(),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          AgriConnectTabSelectorWidget(
            tabs: const ['Communities', 'Messages'],
            activeTab: _activeTab,
            onTabSelected: (index) => setState(() => _activeTab = index),
          ),
          const SizedBox(height: 14),
          Expanded(child: _activeTab == 0 ? _communitiesTab() : _messagesTab()),
        ],
      ),
    );
  }

  Widget _communitiesTab() {
    final discoverAsync = ref.watch(
      discoverCommunitiesProvider((query: _searchQuery, type: null)),
    );
    final myCommunitiesAsync = ref.watch(myCommunitiesProvider);
    final myIds = (myCommunitiesAsync.value ?? const [])
        .map((c) => c.id)
        .toSet();

    return Column(
      children: [
        _searchField(),
        const SizedBox(height: 12),
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
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateCommunityPage(),
                          ),
                        ),
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
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (myComms.isNotEmpty) ...[
                    _sectionHeader('My Communities'),
                    const SizedBox(height: 8),
                    for (final c in myComms)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CommunityCard(
                          community: c,
                          isMember: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CommunityDetailsPage(communityId: c.id),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  _sectionHeader(discover.isEmpty ? '' : 'Discover'),
                  if (discover.isEmpty && myComms.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CommunityDetailsPage(communityId: c.id),
                          ),
                        ),
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

  Widget _messagesTab() {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load messages.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(conversationsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (conversations) {
        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 40,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                const Text('No messages yet.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NewConversationPage(),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Start a conversation'),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final c = conversations[index];
            return ConversationTile(
              conversation: c,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConversationPage(conversationId: c.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _searchField() {
    return TextField(
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
    );
  }

  Widget _sectionHeader(String title) {
    if (title.isEmpty) return const SizedBox.shrink();
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade800,
      ),
    );
  }
}
