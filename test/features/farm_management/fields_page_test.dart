import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/fields_page.dart';

void main() {
  FieldEntity field() => FieldEntity(
        id: 'field-1',
        farmId: 'farm-1',
        fieldName: 'North Field',
        acreage: 4.5,
        soilType: 'Loam',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  testWidgets('FieldCard renders Add Crop and Add Livestock actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FieldCard(
            field: field(),
            onAddCrop: () {},
            onAddLivestock: () {},
          ),
        ),
      ),
    );

    expect(find.text('North Field'), findsOneWidget);
    expect(find.text('Add Crop'), findsOneWidget);
    expect(find.text('Add Livestock'), findsOneWidget);
  });

  testWidgets('FieldCard fires crop and livestock callbacks', (tester) async {
    var cropTapped = false;
    var livestockTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FieldCard(
            field: field(),
            onAddCrop: () => cropTapped = true,
            onAddLivestock: () => livestockTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Crop'));
    expect(cropTapped, isTrue);

    await tester.tap(find.text('Add Livestock'));
    expect(livestockTapped, isTrue);
  });

  testWidgets('FieldCard hides actions when callbacks are absent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FieldCard(field: field())),
      ),
    );

    expect(find.text('Add Crop'), findsNothing);
    expect(find.text('Add Livestock'), findsNothing);
  });
}
