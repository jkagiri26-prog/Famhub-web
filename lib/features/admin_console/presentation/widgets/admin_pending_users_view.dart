/// ============================================================
/// ADMIN → USERS → PENDING / ONBOARDING
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// Users who are not fully onboarded / otherwise pending, according to the
/// deployed status fields. Uses the SAME admin-safe RPC
/// (`users.admin_list_users`) with `p_status = 'pending'` — no new backend
/// source, no client-side filtering of the whole population.
///
/// Search and pagination remain server-side. Reuses the shared admin
/// user-list presentation and the existing permission gating.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_users_provider.dart';
import 'package:famhub_app/features/admin_console/domain/permissions/permissions.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_user_list_widgets.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

class AdminPendingUsersView extends ConsumerStatefulWidget {
  const AdminPendingUsersView({super.key});

  @override
  ConsumerState<AdminPendingUsersView> createState() =>
      _AdminPendingUsersViewState();
}

class _AdminPendingUsersViewState extends ConsumerState<AdminPendingUsersView> {
  static const int _pageSize = 25;

  final _searchController = TextEditingController();
  Timer? _debounce;
  int _page = 0;

  AdminUsersQuery get _query => AdminUsersQuery(
        search: _searchController.text,
        status: 'pending',
        page: _page,
        pageSize: _pageSize,
      );

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _page = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Existing Admin permission gating — backend RPC remains authoritative.
    final capability = ref.watch(
      adminCapabilityStatusProvider(AdminPermissions.usersView),
    );
    if (capability.isLoading) {
      return const LoadingStateWidget(message: 'Checking access...');
    }
    final access = capability.value;
    if (access == null || !access.isAllowed) {
      return PermissionDeniedWidget(
        title: 'Users access denied',
        message: access?.reason ??
            'You do not have permission to view the user directory.',
      );
    }

    final pageAsync = ref.watch(adminUsersProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search pending users by name, email or phone',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        Expanded(
          child: pageAsync.when(
            loading: () => const LoadingStateWidget(
              message: 'Loading pending users...',
            ),
            error: (e, _) => ErrorStateWidget(
              title: 'Failed to load pending users',
              message: 'Could not load pending users. Please try again.',
              retryLabel: 'Retry',
              onRetry: () => ref.invalidate(adminUsersProvider(_query)),
              detailedError: e.toString(),
            ),
            data: (page) => AdminUsersDirectoryBody(
              page: page,
              pageIndex: _page,
              pageSize: _pageSize,
              emptyTitle: 'No pending users',
              emptySubtitle:
                  'There are no users pending onboarding right now.',
              filtering: _searchController.text.trim().isNotEmpty,
              onPrev: _page > 0 ? () => setState(() => _page--) : null,
              onNext: (_page * _pageSize + page.items.length) < page.totalCount
                  ? () => setState(() => _page++)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
