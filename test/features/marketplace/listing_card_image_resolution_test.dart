import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/marketplace/presentation/widgets/listing_card_widget.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 320, child: child),
    ),
  );
}

void main() {
  testWidgets('shows placeholder for a media id, never rendering the id',
      (tester) async {
    const mediaId = '9f1c2a5e-0000-4000-8000-000000000000';

    await tester.pumpWidget(_wrap(const ListingCardWidget(
      title: 'Fresh Tomatoes',
      subtitle: 'Test crop',
      price: 'KSh 150',
      location: 'Nairobi',
      imageUrl: mediaId,
    )));

    expect(find.byIcon(Icons.agriculture_outlined), findsOneWidget);
    expect(find.textContaining(mediaId), findsNothing);
  });

  testWidgets('shows placeholder for a private storage path', (tester) async {
    await tester.pumpWidget(_wrap(const ListingCardWidget(
      title: 'Fresh Tomatoes',
      subtitle: 'Test crop',
      price: 'KSh 150',
      location: 'Nairobi',
      imageUrl: 'listings/stock-1/private-image.webp',
    )));

    expect(find.byIcon(Icons.agriculture_outlined), findsOneWidget);
    expect(find.textContaining('listings/stock-1'), findsNothing);
  });

  testWidgets('shows placeholder when no image is provided', (tester) async {
    await tester.pumpWidget(_wrap(const ListingCardWidget(
      title: 'Fresh Tomatoes',
      subtitle: 'Test crop',
      price: 'KSh 150',
      location: 'Nairobi',
      imageUrl: null,
    )));

    expect(find.byIcon(Icons.agriculture_outlined), findsOneWidget);
  });

  testWidgets('keeps title, price and location visible', (tester) async {
    await tester.pumpWidget(_wrap(const ListingCardWidget(
      title: 'Fresh Tomatoes',
      subtitle: 'Test crop',
      price: 'KSh 150/kg',
      location: 'Nairobi, Kenya',
      imageUrl: null,
    )));

    expect(find.text('Fresh Tomatoes'), findsOneWidget);
    expect(find.text('KSh 150/kg'), findsOneWidget);
    expect(find.text('Nairobi, Kenya'), findsOneWidget);
  });
}
