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

/// Platform modules the backend publishes in `system.modules` but that are
/// deliberately absent from the static `ModuleRegistry` (which only carries
/// workspace modules). Their display names therefore come from
/// `runtimeModuleRegistryProvider`, exactly as they do in production.
const List<RuntimeModule> _platformModules = <RuntimeModule>[
  RuntimeModule(moduleId: 'weather', displayName: 'Weather', route: '/weather'),
  RuntimeModule(moduleId: 'settings', displayName: 'Settings', route: '/settings'),
];

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

  group('assistantContextProvider — platform routes (Weather, Settings)', () {
    test('resolves the Weather route to the Weather module and name', () {
      final f = _fixture(runtimeModules: _platformModules);
      final AssistantContext context = _read(f.container, '/weather');

      expect(context.route, '/weather');
      expect(context.moduleId, 'weather');
      expect(context.moduleName, 'Weather');
      expect(context.toJson()['current_module'], 'Weather');
    });

    test('resolves the module id even before the backend registry loads',
        () {
      final f = _fixture(runtimeModules: const <RuntimeModule>[]);
      final AssistantContext context = _read(f.container, '/weather');

      expect(context.moduleId, 'weather');
      // No name is invented — the envelope simply omits it until the
      // runtime registry supplies one.
      expect(context.moduleName, isNull);
      expect(context.toJson().containsKey('current_module'), isFalse);
    });

    test('resolves a nested Weather route', () {
      final f = _fixture(runtimeModules: _platformModules);

      for (final route in <String>[
        '/weather/hourly',
        '/weather/forecast/daily',
      ]) {
        final AssistantContext context = _read(f.container, route);
        expect(context.moduleId, 'weather', reason: route);
        expect(context.moduleName, 'Weather', reason: route);
      }
    });

    test('resolves the runtime Settings route to the Settings module', () {
      final f = _fixture(runtimeModules: _platformModules);
      final AssistantContext context = _read(f.container, '/settings');

      expect(context.moduleId, 'settings');
      expect(context.moduleName, 'Settings');
    });
  });

  group('assistantContextProvider — prefix boundaries and unknown routes', () {
    test('a sibling that shares a prefix never matches', () {
      final f = _fixture(runtimeModules: _platformModules);

      expect(_read(f.container, '/farmer-tools').moduleId, isNull);
      expect(_read(f.container, '/farms').moduleId, isNull);
      expect(_read(f.container, '/market').moduleId, isNull);
      expect(_read(f.container, '/settings-backup').moduleId, isNull);
      expect(_read(f.container, '/weatherish').moduleId, isNull);

      // …while the real routes still resolve.
      expect(_read(f.container, '/farm').moduleId, 'farm_management');
      expect(_read(f.container, '/weather').moduleId, 'weather');
      expect(_read(f.container, '/settings').moduleId, 'settings');
    });

    test('matches on path segments rather than raw string prefixes', () {
      final f = _fixture(runtimeModules: _platformModules);

      expect(_read(f.container, '/farm/crops').moduleId, 'farm_management');
      expect(_read(f.container, '/farmers').moduleId, isNull);
      // Nested settings page belongs to Profile, not to runtime Settings.
      expect(_read(f.container, '/profile/settings').moduleId, 'profile');
    });

    test('ignores query strings and fragments when identifying the page',
        () {
      final f = _fixture(runtimeModules: _platformModules);
      final AssistantContext context = _read(
        f.container,
        '/marketplace?tab=sell&entity=ent-1',
      );

      expect(context.moduleId, 'marketplace');
      expect(context.moduleName, 'Marketplace');
      // Query values are screen state, not page identity, and are never
      // shipped to the model.
      expect(context.route, '/marketplace');
      expect(context.toJson()['current_page'], '/marketplace');
      expect(
        context.toJson().values.any((v) => v.toString().contains('tab=')),
        isFalse,
      );

      expect(
        _read(f.container, '/farm#crops').moduleId,
        'farm_management',
      );
    });

    test('genuinely unknown routes stay unknown', () {
      final f = _fixture(runtimeModules: _platformModules);

      for (final route in <String>[
        '/nope',
        '/x/y/z',
        '/weatherx',
        '/settings2',
        '/farmer-tools',
      ]) {
        final AssistantContext context = _read(f.container, route);
        expect(context.moduleId, isNull, reason: route);
        expect(context.moduleName, isNull, reason: route);
        expect(
          context.toJson().containsKey('current_module'),
          isFalse,
          reason: route,
        );
      }
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
