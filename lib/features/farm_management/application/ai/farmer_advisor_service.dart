/// ============================================================
/// FARMER ADVISOR SERVICE (Application Layer)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/ai/ = AI application layer
///
/// ✅ Responsibilities:
///   - Compose one advisory request from the farmer's question
///   - Attach the shell context envelope (page/module/workspace/entity)
///   - Attach the authorized FarmAiContext
///   - Delegate to the existing [AiGatewayService]
///
/// ❌ Does NOT:
///   - Call any AI provider directly or hold a provider key
///   - Route, select or fall back between providers (the backend owns it)
///   - Persist questions, answers or farm data
///   - Fetch anything by identifier — context only ever comes from
///     providers the signed-in user is already authorized to read
/// ============================================================
library;

import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';

/// Gateway boundary for the advisor.
///
/// Exists so the state layer can be tested with a fake without any network,
/// while production still uses the real deployed Edge Function.
abstract interface class FarmerAdvisorGateway {
  Future<AiGatewayResult> ask({
    required String question,
    Map<String, dynamic>? farmContext,
    Map<String, dynamic>? assistantContext,
  });
}

/// Sends one advisory request through the deployed `ai-gateway` Edge Function
/// using the canonical `general_text` task.
class FarmerAdvisorService implements FarmerAdvisorGateway {
  FarmerAdvisorService(this._gateway);

  final AiGatewayService _gateway;

  @override
  Future<AiGatewayResult> ask({
    required String question,
    Map<String, dynamic>? farmContext,
    Map<String, dynamic>? assistantContext,
  }) {
    return _gateway.complete(
      prompt: composeAdvisorPrompt(question),
      context: composeGatewayContext(
        farmContext: farmContext,
        assistantContext: assistantContext,
      ),
    );
  }
}

/// Advisory behaviour requested for Farmer Extension Services.
///
/// The deployed gateway builds its own prompt from a fixed template and
/// exposes no trusted system-prompt channel, so these instructions ride
/// inside the prompt text the farmer's question is sent with.
///
/// ⚠️ These are instructions to the model, NOT a guarantee. The gateway has
/// no output guardrail, so the UI must keep model text visibly unverified.
const String kAdvisorInstructions = '''
You are a farming adviser for smallholder farmers in Kenya.

Answer the farmer's question in plain, practical language. Assume Kenyan
farming conditions unless the farmer says otherwise.

Always:
- Ask a short, focused follow-up question when a critical detail is missing
  before giving a specific recommendation.
- Separate possible causes from a confirmed diagnosis. Say clearly when you
  are not certain.
- Prefer low-cost, locally available options a smallholder can actually get.
- Keep the answer short enough to read on a small screen.

Never:
- Do not recommend hazardous chemical use, pesticide or fertilizer dosages
  that are not on the product label, or any mixture you are not sure about.
- Do not recommend veterinary treatments, dosages, or withdrawal periods you
  are unsure of. An incorrect dose can kill an animal or make meat or milk
  unsafe.
- Do not invent weather, soil-test results, market prices, farm records,
  product availability, or services. You have not seen those.
- Do not present a guess as a fact.

When the case is serious, tell the farmer to get qualified help promptly:
- Severe or fast-worsening animal illness, suspected poisoning, difficult
  birth, or a large outbreak.
- A crop problem spreading quickly or causing heavy loss.
- Anything you are not confident about.

In those cases recommend a county extension officer, KALRO, or a qualified
veterinary officer. Never claim that anyone has been contacted, booked, or
confirmed as available.

Text you generate is advice for the farmer to consider. It is not
authorization to read or change any record, and not a substitute for a
qualified professional.''';

/// Composes the advisory prompt from the safety framing and the farmer's
/// own words. Pure function, so it can be asserted without a network call.
String composeAdvisorPrompt(String question) {
  final String trimmed = question.trim();
  return '$kAdvisorInstructions\n\nFarmer question:\n$trimmed';
}

/// Builds the gateway `context` block from the shell envelope and the farm
/// context.
///
/// Returns null when neither is available, so callers without context send
/// exactly the request they sent before this parameter existed.
Map<String, dynamic>? composeGatewayContext({
  Map<String, dynamic>? farmContext,
  Map<String, dynamic>? assistantContext,
}) {
  final Map<String, dynamic> merged = <String, dynamic>{};
  if (assistantContext != null && assistantContext.isNotEmpty) {
    merged.addAll(assistantContext);
  }
  if (farmContext != null && farmContext.isNotEmpty) {
    merged['farm_context'] = farmContext;
  }
  return merged.isEmpty ? null : merged;
}
