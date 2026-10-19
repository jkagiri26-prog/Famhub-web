/// ============================================================
/// ASSISTANT CAPABILITY SEAM
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/application/assistant/ = shell-level assistant seam
///
/// ✅ PURPOSE:
///   Give the shared shell assistant a *closed* way to ask one approved
///   application service for real data, and hand that data to the existing
///   AI gateway as evidence for the model to explain.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - A capability is selected by a cheap, local, side-effect free
///     [AssistantCapability.matches] test on the user's own words
///   - Execution lives entirely inside the capability, which calls an
///     existing authorized application service — never a raw query, RPC,
///     URL or arbitrary code path
///   - The model is never in the loop for selection or execution: it only
///     interprets the evidence the application already retrieved
///   - Extensible by adding another [AssistantCapability] to the composing
///     list; no new registry, no parallel chat system
///
/// ❌ Does NOT:
///   - Grant permissions. Authorization stays with Supabase RLS and the
///     Edge Function that actually serves the data
///   - Let the model request a capability, an identifier, or a scope
///   - Persist anything
/// ============================================================
library;

import 'package:flutter/foundation.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';

/// What a capability run produced.
enum AssistantCapabilityOutcomeKind {
  /// The capability needs one short answer from the user before it can run
  /// (for example which farm). No data was fetched and the gateway is not
  /// called.
  clarification,

  /// The capability could not produce evidence. Reported honestly — the
  /// assistant never invents a value to fill the gap. The gateway is not
  /// called.
  failure,

  /// Evidence was retrieved from an authorized application service and is
  /// ready to be handed to the gateway for interpretation.
  evidence,
}

/// Result of one capability run.
@immutable
class AssistantCapabilityOutcome {
  const AssistantCapabilityOutcome.clarification({
    required this.capabilityId,
    required this.text,
    this.options = const <String>[],
  })  : kind = AssistantCapabilityOutcomeKind.clarification,
        code = null,
        evidence = null;

  const AssistantCapabilityOutcome.failure({
    required this.capabilityId,
    required this.code,
    required this.text,
  })  : kind = AssistantCapabilityOutcomeKind.failure,
        evidence = null,
        options = const <String>[];

  const AssistantCapabilityOutcome.evidence({
    required this.capabilityId,
    required this.evidence,
  })  : kind = AssistantCapabilityOutcomeKind.evidence,
        code = null,
        text = null,
        options = const <String>[];

  final AssistantCapabilityOutcomeKind kind;

  /// Stable identifier of the capability that produced this outcome.
  final String capabilityId;

  /// The clarification question, or the honest failure message. Never a
  /// fabricated value.
  final String? text;

  /// Machine-readable failure code. Never contains provider detail.
  final String? code;

  /// Minimal, already-redacted context for the gateway. Never raw records.
  final Map<String, dynamic>? evidence;

  /// The names offered in this clarification, in the order they were
  /// listed to the farmer. Lets a short reply ("the second one") be
  /// matched against what was actually offered instead of guessed at.
  /// Empty for outcomes that asked no question.
  final List<String> options;
}

/// One approved application capability the assistant may invoke.
///
/// Implementations must be side-effect free apart from reading data, and
/// must resolve every identifier from state the signed-in user is already
/// authorized to read. A capability must never accept an identifier that
/// arrived from the user's free text or from the model.
abstract interface class AssistantCapability {
  /// Stable id used in evidence and diagnostics (for example `farm_weather`).
  String get id;

  /// Cheap, local, no I/O. True when this capability claims the request.
  ///
  /// Must be conservative: anything it does not clearly claim is answered
  /// through the ordinary advisory path.
  bool matches(String question);

  /// Executes the capability: resolves authorized inputs, calls the existing
  /// application service, and returns evidence or an honest outcome.
  ///
  /// Never throws for ordinary failures — those become
  /// [AssistantCapabilityOutcome.failure].
  Future<AssistantCapabilityOutcome> run({
    required String question,
    required AssistantContext assistantContext,
  });
}
