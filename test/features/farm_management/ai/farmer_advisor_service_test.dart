import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_service.dart';

void main() {
  group('composeAdvisorPrompt', () {
    test('includes the safety framing and the farmer question', () {
      final String prompt = composeAdvisorPrompt('My maize leaves are yellow.');

      expect(prompt, contains('My maize leaves are yellow.'));
      expect(prompt, contains(kAdvisorInstructions));
      expect(prompt, contains('Farmer question:'));
    });

    test('carries the Kenyan smallholder framing', () {
      expect(composeAdvisorPrompt('x'), contains('Kenyan'));
    });

    test('instructs the model to separate uncertainty from diagnosis', () {
      final String prompt = composeAdvisorPrompt('x');

      expect(prompt, contains('possible causes'));
      expect(prompt, contains('confirmed diagnosis'));
      expect(prompt, contains('not certain'));
    });

    test('instructs the model not to recommend risky treatments', () {
      final String prompt = composeAdvisorPrompt('x');

      expect(prompt, contains('hazardous chemical use'));
      expect(prompt, contains('not on the product label'));
      expect(prompt, contains('withdrawal periods'));
    });

    test('instructs the model not to invent facts', () {
      final String prompt = composeAdvisorPrompt('x');

      expect(prompt, contains('Do not invent weather'));
      expect(prompt, contains('market prices'));
      expect(prompt, contains('product availability'));
    });

    test('routes urgent cases to a qualified professional', () {
      final String prompt = composeAdvisorPrompt('x');

      expect(prompt, contains('county extension officer'));
      expect(prompt, contains('KALRO'));
      expect(prompt, contains('veterinary officer'));
    });

    test('forbids claiming anyone was contacted or booked', () {
      expect(
        composeAdvisorPrompt('x'),
        contains('Never claim that anyone has been contacted, booked'),
      );
    });

    test('states that generated text is advice, not authorization', () {
      final String prompt = composeAdvisorPrompt('x');

      expect(prompt, contains('not\nauthorization to read or change any record'));
    });

    test('trims the farmer question', () {
      final String prompt = composeAdvisorPrompt('   My goat is lame.   ');

      expect(prompt, endsWith('Farmer question:\nMy goat is lame.'));
      expect(prompt, isNot(contains('   My goat is lame.   ')));
    });

    test('keeps an empty question in place so the gateway can reject it', () {
      // The service layer does not silently drop blank input; the gateway
      // reports `empty_prompt`. Composition only trims.
      expect(composeAdvisorPrompt('   '), endsWith('Farmer question:\n'));
    });
  });

  group('composeGatewayContext', () {
    const Map<String, dynamic> farm = <String, dynamic>{
      'stage': 'growing',
      'healthScore': 78,
    };

    test('returns null when neither source has anything to send', () {
      expect(composeGatewayContext(), isNull);
      expect(composeGatewayContext(farmContext: null), isNull);
      expect(
        composeGatewayContext(
          farmContext: <String, dynamic>{},
          assistantContext: <String, dynamic>{},
        ),
        isNull,
      );
    });

    test('sends only the assistant envelope when there is no farm context',
        () {
      final Map<String, dynamic>? merged = composeGatewayContext(
        assistantContext: const <String, dynamic>{'current_page': '/farm'},
      );

      expect(merged, isNotNull);
      expect(merged!['current_page'], '/farm');
      expect(merged.containsKey('farm_context'), isFalse);
    });

    test('nests the farm context so it cannot collide with the envelope',
        () {
      final Map<String, dynamic>? merged = composeGatewayContext(
        farmContext: farm,
        assistantContext: const <String, dynamic>{'current_page': '/farm'},
      );

      expect(merged, isNotNull);
      expect(merged!['current_page'], '/farm');
      expect(merged['farm_context'], farm);
      // The farm fields stay under farm_context and never float to the top.
      expect(merged.containsKey('stage'), isFalse);
      expect(merged.containsKey('healthScore'), isFalse);
    });

    test('promotes the shell envelope to the top level', () {
      const AssistantContext context = AssistantContext(
        route: '/farm',
        moduleId: 'farm_management',
        moduleName: 'Farm Management',
        workspaceName: 'Kibuye Farm',
        workspaceType: 'farmer',
        contextMode: 'farmer',
        entityName: 'Kibuye Farm',
      );

      final Map<String, dynamic>? merged = composeGatewayContext(
        farmContext: farm,
        assistantContext: context.toJson(),
      );

      expect(merged, isNotNull);
      expect(merged!['current_module'], 'Farm Management');
      expect(merged['active_workspace'], 'Kibuye Farm');
      expect(merged['context_mode'], 'farmer');
      expect(merged['active_entity'], 'Kibuye Farm');
      // Labels only — no identifier ever reaches the model.
      expect(merged.containsKey('entity_id'), isFalse);
      expect(merged.containsKey('entityId'), isFalse);
    });

    test('sends the farm context on its own when the shell has no context',
        () {
      final Map<String, dynamic>? merged = composeGatewayContext(
        farmContext: farm,
      );

      expect(merged, isNotNull);
      expect(merged!['farm_context'], farm);
      expect(merged.containsKey('current_page'), isFalse);
    });
  });
}
