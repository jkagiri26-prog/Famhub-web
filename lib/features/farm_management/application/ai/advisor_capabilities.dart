/// ============================================================
/// ADVISOR CAPABILITIES — composition list
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/ai/ = AI application layer
///
/// ✅ PURPOSE:
///   The one ordered list of approved capabilities the shell assistant may
///   invoke. Selection is first-match on [AssistantCapability.matches].
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - A plain composition list, not a registry: adding a capability is one
///     line here plus its own feature implementation
///   - The shell never sees this list — it only opens the assistant through
///     AssistantLauncherRegistry
///   - Future Farm Management / Marketplace / Financing capabilities append
///     here without touching selection, execution or the gateway
///
/// ❌ Does NOT:
///   - Let the model add, reorder or invoke a capability
///   - Fall through to a "do anything" agent when nothing matches — an
///     unmatched question keeps the ordinary advisory path
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_crop_capability.dart';
import 'package:famhub_app/features/weather/application/assistant/farm_weather_capability.dart';

/// Approved capabilities, in the order they are offered the request.
final advisorCapabilitiesProvider = Provider<List<AssistantCapability>>((
  ref,
) {
  return <AssistantCapability>[
    ref.watch(farmWeatherCapabilityProvider),
    ref.watch(farmCropCapabilityProvider),
  ];
});
