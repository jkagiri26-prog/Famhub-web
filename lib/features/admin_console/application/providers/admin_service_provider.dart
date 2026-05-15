import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/admin_governance_service.dart';

final adminServiceProvider =
    Provider((ref) => AdminGovernanceService());