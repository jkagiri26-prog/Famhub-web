/// ============================================================
/// DEV AI GATEWAY TEST PAGE (PHASE 2D — TEMPORARY)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/ai_assistant/presentation/pages/ = AI screens
///
/// ⚠️ DEVELOPER-ONLY — VISIBLE ONLY WHEN BUILT WITH
///   --dart-define=AI_GATEWAY_DEV_PROBE=true  (see [aiGatewayDevProbe]).
///   Phase 2D proves the deployed `ai-gateway` Edge Function end to
///   end from the real authenticated app:
///
///   Flutter → authenticated Supabase session → `/functions/v1/ai-gateway`
///   → real AI provider → response back to Flutter.
///
/// ✅ Responsibilities:
///   - Confirm a Supabase session exists before calling
///   - Send the fixed Phase 2D request contract
///   - Surface status / ok / request_id / output / error / elapsed
///
/// ❌ Does NOT:
///   - Hold provider API keys
///   - Implement provider selection, routing or fallback
///   - Persist chats, usage or billing
///   - Exist at all unless built with AI_GATEWAY_DEV_PROBE=true
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/dev_ai_gateway_probe.dart';
import 'package:famhub_app/shared/layouts/shell_page_content.dart';

class DevAiGatewayTestPage extends StatefulWidget {
  const DevAiGatewayTestPage({super.key});

  @override
  State<DevAiGatewayTestPage> createState() => _DevAiGatewayTestPageState();
}

class _DevAiGatewayTestPageState extends State<DevAiGatewayTestPage> {
  DevAiGatewayResult? _result;
  DevAiGatewayTarget? _active;
  bool _running = false;
  String? _authError;

  Future<void> _run(DevAiGatewayTarget target) async {
    final supabase = SupabaseService.instance;
    final session = supabase.currentSession;
    final token = supabase.accessToken;

    if (session == null || token == null || token.isEmpty) {
      setState(() {
        _result = null;
        _authError =
            'No authenticated Supabase session. Sign in first — this screen '
            'never starts a login flow.';
      });
      return;
    }

    setState(() {
      _running = true;
      _active = target;
      _authError = null;
      _result = null;
    });

    final stopwatch = Stopwatch()..start();
    DevAiGatewayResult result;
    try {
      // `invoke` resolves to <project>/functions/v1/ai-gateway and the
      // explicit Authorization header carries the current session token.
      final response = await supabase.client.functions
          .invoke(
            DevAiGatewayRequest.functionName,
            headers: DevAiGatewayRequest.buildHeaders(
              target: target,
              accessToken: token,
            ),
            body: DevAiGatewayRequest.body,
          )
          .timeout(DevAiGatewayRequest.timeout);
      stopwatch.stop();
      result = parseDevAiGatewayResponse(
        target: target,
        statusCode: response.status,
        data: response.data,
        elapsed: stopwatch.elapsed,
      );
    } catch (error) {
      stopwatch.stop();
      result = parseDevAiGatewayFailure(
        target: target,
        error: error,
        elapsed: stopwatch.elapsed,
      );
    }

    if (!mounted) return;
    setState(() {
      _running = false;
      _active = null;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!aiGatewayDevProbe) {
      return const ShellPageContent(
        title: 'AI Gateway Test',
        child: Center(
          child: Text(
            'This developer screen is unavailable in this build.',
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final supabase = SupabaseService.instance;
    final session = supabase.currentSession;
    final token = supabase.accessToken;
    final hasAuth = session != null && token != null && token.isNotEmpty;

    return ShellPageContent(
      title: 'AI Gateway Test',
      subtitle: 'Phase 2D · developer-only · debug builds',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthCard(
            theme: theme,
            hasAuth: hasAuth,
            userId: session?.user.id,
            userEmail: session?.user.email,
            error: _authError,
          ),
          const SizedBox(height: 12),
          _buildRequestCard(theme, hasAuth),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final target in DevAiGatewayTarget.values)
                OutlinedButton.icon(
                  onPressed:
                      (_running || !hasAuth) ? null : () => _run(target),
                  icon: _running && _active == target
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(target.sendsProviderSelector
                          ? Icons.tune
                          : Icons.bolt_outlined,
                          size: 16),
                  label: Text(target.buttonLabel),
                ),
            ],
          ),
          if (_running) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            Text(
              'Running ${_active?.buttonLabel ?? ''}… '
              '(client timeout ${DevAiGatewayRequest.timeout.inSeconds}s)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_result != null) _ResultCard(theme: theme, result: _result!),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ThemeData theme, bool hasAuth) {
    const bodyJson = '{"task":"general","input":"Reply with the word OK."}';
    final authLine =
        'Authorization: Bearer <${hasAuth ? 'current Supabase access token' : 'MISSING'}>';
    final lastRun = _active ?? _result?.target;

    return _section(
      theme,
      title: 'Request contract',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(theme, 'Method + URL', 'POST ${DevAiGatewayRequest.path}'),
          _kv(theme, 'Content-Type', 'application/json'),
          _kv(theme, 'Authorization', authLine),
          _kv(theme, 'Body', bodyJson),
          const SizedBox(height: 4),
          _kv(theme, 'Provider selector header', ''),
          for (final target in DevAiGatewayTarget.values)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                '• ${target.buttonLabel}: '
                '${DevAiGatewayRequest.providerHeaderName}: '
                '${target.providerSelector ?? '(omitted)'}'
                '${lastRun == target ? '   ← last run' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: lastRun == target
                      ? theme.colorScheme.primary
                      : Colors.grey.shade700,
                  fontWeight:
                      lastRun == target ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Auth card ──────────────────────────────────────────────

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.theme,
    required this.hasAuth,
    required this.userId,
    required this.userEmail,
    required this.error,
  });

  final ThemeData theme;
  final bool hasAuth;
  final String? userId;
  final String? userEmail;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return _section(
      theme,
      title: 'Authentication',
      accent: hasAuth ? Colors.green : Colors.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(theme, 'Session', hasAuth ? 'present' : 'MISSING'),
          if (hasAuth) ...[
            if (userEmail != null) _kv(theme, 'Email', userEmail!),
            _kv(theme, 'User id', userId ?? 'unknown'),
            _kv(theme, 'Access token', 'present (not displayed)'),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Result card ────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.theme, required this.result});

  final ThemeData theme;
  final DevAiGatewayResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.succeeded;
    final color = ok ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${result.verdict} · ${result.target.buttonLabel}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                result.elapsedLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _kv(
            theme,
            'HTTP status',
            result.statusCode?.toString() ?? 'no response received',
          ),
          _kv(theme, 'ok', result.ok?.toString() ?? 'absent'),
          _kv(theme, 'request_id', result.requestId ?? 'absent'),
          _kv(
            theme,
            'output',
            result.hasOutput ? result.output! : 'absent / empty',
            multiline: true,
          ),
          if (result.error != null)
            _kv(theme, 'error', result.error!, multiline: true, danger: true),
          if (result.transportError != null)
            _kv(
              theme,
              'transport',
              result.transportError!,
              multiline: true,
              danger: true,
            ),
          if (result.corsSuspected) ...[
            const SizedBox(height: 8),
            Text(
              'Likely CORS preflight rejection in the browser. '
              'The custom "${DevAiGatewayRequest.providerHeaderName}" header '
              'must be allowed by the Edge Function\'s Access-Control-Allow-Headers. '
              'Report as Phase 2D CORS finding — do not change the gateway here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (result.rawBody != null && !ok) ...[
            const SizedBox(height: 12),
            Text(
              'Raw response',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              result.rawBody!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── shared bits ────────────────────────────────────────────

Widget _section(
  ThemeData theme, {
  required String title,
  required Widget child,
  Color? accent,
}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: accent ?? Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

Widget _kv(
  ThemeData theme,
  String label,
  String value, {
  bool multiline = false,
  bool danger = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            color: danger ? Colors.red.shade700 : Colors.black87,
            fontWeight: danger ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}
