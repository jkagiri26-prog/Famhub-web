import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/infrastructure/services/admin_governance_service.dart';

final adminServiceProvider =
    Provider((ref) => AdminGovernanceService());