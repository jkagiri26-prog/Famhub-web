import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/access_policy.dart';
import '../infrastructure/repositories/access_policy_repository.dart';

final accessPolicyRepositoryProvider =
    Provider((ref) => AccessPolicyRepository());

final accessPolicyProvider =
    FutureProvider<AccessPolicy>((ref) async {
  final repo = ref.watch(accessPolicyRepositoryProvider);
  return repo.fetchPolicy();
});