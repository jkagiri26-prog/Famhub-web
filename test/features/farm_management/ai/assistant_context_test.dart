import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';
import 'package:famhub_app/core/context_engine/controllers/context_controller.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context_provider.dart';
import 'package:famhub_app/core/workspace/application/current_workspace_contexts_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';

/// Replaces the real context engine with a fixed, signed-in context.
class _FixedContextController extends ContextController {
  _FixedContextController(this.context);

  final EntityContext context;

  @override
  EntityContext build() => context;
}

({ProviderContainer container}) _fixture({
  String? workspaceType = 'farmer',
  String? workspaceName = 'Kibuye Farm',
  EntityContext context = const EntityContext(
    role: 'farmer',
    entityId: 'ent-1',
    isGuest: false,
    isLoading: false,
  ),
  List<Map<String, dynamic>> contexts = const <Map<String, dynamic>>[],
  List<RuntimeModule> runtimeModules = const <RuntimeModule>[],
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      activeWorkspaceTypeProvider.overrideWithValue(workspaceType),
      activeWorkspaceNameProvider.overrideWithValue(workspaceName),
      contextProvider.overrideWith(() => _FixedContextController(context)),
      currentWorkspaceContextsProvider.overrideWithValue(
        AsyncData<List<Map<String, dynamic>>>(contexts),
      ),
      runtimeModuleRegistryProvider.overrideWithValue(runtimeModules),
    ],
  );
  addTearDown(container.dispose);
  return (container: container);
}

AssistantContext _read(ProviderContainer container, String route) {
  return container.read(assistantContextProvider(route));
}

void main() {
  group('assistantContextProvider — route resolution', () {
    test('resolves a known route to its module id and display name', () {
      final f = _fixture();
      final AssistantContext context = _read(f.container, '/farm');

      expect(context.route, '/farm');
      expect(context.moduleId, 'farm_management');
      expect(context.moduleName, 'Farm Management');
    });

    test('resolves the Extension Services route', () {
      final f = _fixture(workspaceType: 'service_provider');
      final AssistantContext context = _read(f.container, '/extension');

      expect(context.moduleId, 'extension_services');
      expect(context.moduleName, isNotEmpty);
    });

    test('resolves a nested path by longest prefix, not exact match', () {
      final f = _fixture();
      final AssistantContext context = _read(f.container, '/farm/crops');

      expect(context.moduleId, 'farm_management');
      expect(context.moduleName, 'Farm Management');
    });

    test('does not confuse sibling routes that share a prefix', () {
      // `/marketplace` must not be swallowed by `/market`.
      final f = _fixture();
      final AssistantContext context = _read(f.container, '/marketplace');

      expect(context.moduleId, 'marketplace');
    });

    test('maps the landing route to the workspace primary module', () {
      final f = _fixture();
      final AssistantContext context = _read(f.container, '/');

      expect(context.moduleId, 'farm_management');
      expect(context.moduleName, 'Farm Management');
    });

    test('leaves the landing route unresolved without a workspace type', () {
      final f = _fixture(workspaceType: null);
      final AssistantContext context = _read(f.container, '/');

      expect(context.moduleId, isNull);
      expect(context.moduleName, isNull);
    });

    test('returns null module for a route that maps to no module', () {
      final f = _fixture();
      final AssistantContext context = _read(f.container, '/not-a-real-page');

      expect(context.moduleId, isNull);
      expect(context.moduleName, isNull);
      // The route itself is still reported honestly.
      expect(context.route, '/not-a-real-page');
    });

    test('returns null module for an empty route', () {
      final f = _fixture();
      final AssistantContext context = _read(f.container, '');

      expect(context.moduleId, isNull);
      expect(context.moduleName, isNull);
    });

    test('prefers the backend runtime display name over the static catalog',
        () {
      final f = _fixture(
        runtimeModules: <RuntimeModule>[
          const RuntimeModule(
            moduleId: 'farm_management',
            displayName: 'Farms (live)',
            route: '/farm',
          ),
        ],
      );

      expect(_read(f.container, '/farm').moduleName, 'Farms (live)');
    });
  });

  group('assistantContextProvider — workspace and mode', () {
    test('carries the active workspace display name', () {
      final f = _fixture(workspaceName: 'Nyeri Growers');
      final AssistantContext context = _read(f.container, '/farm');

      expect(context.workspaceName, 'Nyeri Growers');
      expect(context.workspaceType, 'farmer');
      expect(context.contextMode, 'farmer');
    });

    test('omits an unknown workspace name rather than inventing one', () {
      final f = _fixture(workspaceName: null, workspaceType: null);
      final AssistantContext context = _read(f.container, '/farm');

      expect(context.workspaceName, isNull);
      expect(context.workspaceType, isNull);
      expect(context.toJson().containsKey('active_workspace'), isFalse);
    });
  });

  group('assistantContextProvider — entity name resolution', () {
    test('resolves the active entity to its display name', () {
      final f = _fixture(
        contexts: <Map<String, dynamic>>[
          <String, dynamic>{
            'entity_id': 'ent-1',
            'entity_name': 'Kibuye Farm',
          },
          <String, dynamic>{
            'entity_id': 'ent-2',
            'entity_name': 'Other Farm',
          },
        ],
      );
      final AssistantContext context = _read(f.container, '/farm');

      expect(context.entityName, 'Kibuye Farm');
      expect(context.toJson()['active_entity'], 'Kibuye Farm');
    });

    test('never resolves an entity the user is not authorized to see', () {
      final f = _fixture(
        contexts: <Map<String, dynamic>>[
          <String, dynamic>{
            'entity_id': 'ent-2',
            'entity_name': 'Other Farm',
          },
        ],
      );
      final AssistantContext context = _read(f.container, '/farm');

      expect(context.entityName, isNull);
      // No raw identifier leaks into the model-facing payload.
      expect(context.toJson().containsKey('active_entity'), isFalse);
      expect(
        context.toJson().values.any((v) => v.toString() == 'ent-1'),
        isFalse,
      );
    });

    test('falls back to alternate name keys when entity_name is blank', () {
      final f = _fixture(
        contexts: <Map<String, dynamic>>[
          <String, dynamic>{
            'entity_id': 'ent-1',
            'entity_name': '   ',
            'entity_display_name': 'Kibuye Estate',
          },
        ],
      );

      expect(_read(f.container, '/farm').entityName, 'Kibuye Estate');
    });

    test('returns null when no entity is active', () {
      final f = _fixture(
        context: const EntityContext(
          role: 'farmer',
          isGuest: false,
          isLoading: false,
        ),
      );
      final AssistantContext context = _read(f.container, '/farm');

      expect(context.entityName, isNull);
      expect(context.toJson().containsKey('active_entity'), isFalse);
    });
  });

  group('AssistantContext.toJson', () {
    test('emits only human-readable labels', () {
      const AssistantContext context = AssistantContext(
        route: '/farm',
        moduleId: 'farm_management',
        moduleName: 'Farm Management',
        workspaceName: 'Kibuye Farm',
        workspaceType: 'farmer',
        contextMode: 'farmer',
        entityName: 'Kibuye Farm',
      );

      expect(context.toJson(), <String, dynamic>{
        'current_page': '/farm',
        'current_module': 'Farm Management',
        'active_workspace': 'Kibuye Farm',
        'context_mode': 'farmer',
        'active_entity': 'Kibuye Farm',
      });
    });

    test('never serializes the module id, even when it is known', () {
      const AssistantContext context = AssistantContext(
        route: '/farm',
        moduleId: 'farm_management',
        moduleName: 'Farm Management',
      );

      expect(context.toJson().containsKey('moduleId'), isFalse);
      expect(context.toJson().containsKey('module_id'), isFalse);
      expect(
        context.toJson().values.any((v) => v == 'farm_management'),
        isFalse,
      );
    });

    test('omits every unknown field instead of guessing', () {
      const AssistantContext context = AssistantContext(route: '/unknown');

      expect(context.toJson(), <String, dynamic>{
        'current_page': '/unknown',
      });
    });
  });

  group('AssistantContext.visibleLabels', () {
    test('drops empty and unknown values', () {
      const AssistantContext context = AssistantContext(
        route: '/farm',
        moduleName: 'Farm Management',
        entityName: null,
        contextMode: 'farmer',
      );

      expect(context.visibleLabels, <String>['Farm Management', 'farmer']);
    });

    test('shows the entity instead of the mode when both are known', () {
      const AssistantContext context = AssistantContext(
        route: '/farm',
        moduleName: 'Farm Management',
        workspaceName: 'Kibuye Farm',
        entityName: 'Kibuye Farm',
        contextMode: 'farmer',
      );

      expect(context.visibleLabels, <String>[
        'Farm Management',
        'Kibuye Farm',
        'Kibuye Farm',
      ]);
    });

    test('is empty when only the route is known', () {
      const AssistantContext context = AssistantContext(route: '/x');

      expect(context.visibleLabels, isEmpty);
    });
  });
}
