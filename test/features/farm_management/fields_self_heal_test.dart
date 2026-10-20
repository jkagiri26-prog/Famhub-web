import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/context_engine/controllers/context_controller.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

/// Resolved (non-loading) context so farmContextProvider/fieldsProvider
/// don't require a real Supabase instance in this unit test.
class _ResolvedContextController extends ContextController {
  @override
  EntityContext build() => const EntityContext(
        entityId: 'entity-1',
        isGuest: false,
        isLoading: false,
      );
}

class _FakeFarmRepository implements FarmRepository {
  _FakeFarmRepository(this.fieldsByFarm);
  final Map<String, List<FieldEntity>> fieldsByFarm;
  int getFieldsCalls = 0;

  @override
  Future<List<FieldEntity>> getFields({required String farmId}) async {
    getFieldsCalls++;
    await Future<void>.delayed(Duration.zero); // yield like a real call
    return fieldsByFarm[farmId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FieldEntity _field(String id, String farmId) => FieldEntity(
      id: id,
      farmId: farmId,
      fieldName: 'Field $id',
      createdAt: DateTime(2024),
    );

FarmEntity _farm(String id) => FarmEntity(
      id: id,
      farmName: 'Farm $id',
      isActive: true,
      isVerified: false,
    );

void main() {
  test(
      'fieldsProvider self-heals after invalidation on reset→reopen of the '
      'same farm (no infinite spinner)', () async {
    final farm = _farm('f1');
    final repo = _FakeFarmRepository({'f1': [_field('a', 'f1')]});

    final container = ProviderContainer(overrides: [
      farmRepositoryProvider.overrideWithValue(repo),
      contextProvider.overrideWith(_ResolvedContextController.new),
    ]);
    addTearDown(container.dispose);

    // 1. Open the farm → fields load (self-heal from build()).
    container.read(hierarchyProvider.notifier).selectEntity(farm);
    container.read(fieldsProvider); // first access builds + schedules load
    await pumpEventQueue();

    var state = container.read(fieldsProvider);
    expect(state.isLoading, false);
    expect(state.fields, hasLength(1));
    final callsAfterFirstLoad = repo.getFieldsCalls;
    expect(callsAfterFirstLoad, greaterThan(0));

    // 2. Reset (back to list) → cascade invalidates fieldsProvider.
    container.read(hierarchyProvider.notifier).reset();
    await pumpEventQueue();

    // 3. Re-open the SAME farm from the list.
    container.read(hierarchyProvider.notifier).selectEntity(farm);

    // Simulate the cascade coordinator's post-frame invalidate that used
    // to race with (and clobber) a manual loadFields, leaving the provider
    // stuck at isLoading:true forever.
    container.invalidate(fieldsProvider);
    container.read(fieldsProvider); // rebuild + schedule self-load
    await pumpEventQueue();

    state = container.read(fieldsProvider);
    // Must NOT be stuck spinning — self-loading reloads after invalidate.
    expect(state.isLoading, false,
        reason: 'fieldsProvider must self-heal after invalidation');
    expect(state.fields, hasLength(1));
    expect(repo.getFieldsCalls, greaterThan(callsAfterFirstLoad));
  });
}
