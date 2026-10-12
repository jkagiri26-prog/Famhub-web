import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/infrastructure/data_sources/financing_catalogue_remote_data_source.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_product_card_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_status_chip_widget.dart';

/// Column lists must match the migration's CHECK constraints and public views
/// exactly. These are contract assertions, not behavioural tests.
void main() {
  group('Financing catalogue enum ↔ SQL contract', () {
    test('provider_type values match the SQL CHECK constraint', () {
      expect(
        FinancialPartnerType.values.map(partnerTypeToDb).toSet(),
        {
          'bank',
          'sacco',
          'insurance',
          'microfinance',
          'lending_platform',
          'mobile_money',
        },
      );
      for (final type in FinancialPartnerType.values) {
        expect(partnerTypeFromDb(partnerTypeToDb(type)), type);
      }
      expect(partnerTypeFromDb('nope'), isNull);
    });

    test('verification_status values match the SQL CHECK constraint', () {
      expect(
        FinancingVerificationStatus.values.map((s) => s.dbValue).toSet(),
        {'pending', 'verified', 'rejected', 'suspended'},
      );
      expect(FinancingVerificationStatus.fromDb('verified'),
          FinancingVerificationStatus.verified);
      expect(FinancingVerificationStatus.fromDb(null),
          FinancingVerificationStatus.pending);
    });

    test('approval_status values match the SQL CHECK constraint', () {
      expect(
        FinancingApprovalStatus.values.map((s) => s.dbValue).toSet(),
        {'draft', 'in_review', 'approved', 'rejected'},
      );
      // Absent from the public view → must resolve to null, never a default.
      expect(FinancingApprovalStatus.fromDb(null), isNull);
      expect(FinancingApprovalStatus.fromDb('in_review'),
          FinancingApprovalStatus.inReview);
    });

    test('product_type and interest_rate_type match the SQL CHECK constraints', () {
      expect(
        FinancingProductType.values.map((t) => t.dbValue).toSet(),
        {
          'loan',
          'insurance',
          'savings',
          'asset_financing',
          'input_financing',
          'mobile_money',
        },
      );
      expect(
        FinancingRateType.values.map((t) => t.dbValue).toSet(),
        {'fixed', 'reducing_balance', 'flat', 'variable'},
      );
      expect(FinancingProductType.fromDb('savings'), FinancingProductType.savings);
      expect(FinancingRateType.fromDb('reducing_balance'),
          FinancingRateType.reducingBalance);
    });
  });

  group('Data source column lists', () {
    const forbidden = [
      'metadata',
      'verification_notes',
      'approval_notes',
      'verified_by',
      'approved_by',
      'published_by',
      'created_by',
    ];

    test('no selection ever includes a private column', () {
      for (final columns in const [
        FinancingColumns.publicProvider,
        FinancingColumns.publicProduct,
        FinancingColumns.managedProvider,
        FinancingColumns.managedProduct,
      ]) {
        final selected =
            columns.split(',').map((c) => c.trim()).toSet();
        for (final column in forbidden) {
          expect(selected, isNot(contains(column)),
              reason: '"$column" must never be selected');
        }
      }
    });

    test('browse selections match the public views column-for-column', () {
      expect(
        FinancingColumns.publicProvider.split(',').map((c) => c.trim()),
        [
          'id', 'slug', 'name', 'provider_type', 'description', 'logo_url',
          'website_url', 'country_code', 'is_active', 'verification_status',
          'created_at', 'updated_at',
        ],
      );
      expect(
        FinancingColumns.publicProduct.split(',').map((c) => c.trim()),
        [
          'id', 'provider_id', 'slug', 'name', 'product_type', 'summary',
          'description', 'currency', 'min_amount', 'max_amount',
          'interest_rate', 'interest_rate_type', 'min_tenure_days',
          'max_tenure_days', 'requires_collateral', 'requirements',
          'is_active', 'is_published', 'created_at', 'updated_at',
        ],
      );
    });
  });

  group('Model parsing from the public view shape', () {
    test('provider keeps only public columns', () {
      final provider = FinancingProvider.fromMap(const {
        'id': 'p1',
        'slug': 'equity-bank',
        'name': 'Equity Bank',
        'provider_type': 'bank',
        'description': 'Farm loans',
        'logo_url': null,
        'website_url': 'https://example.com',
        'country_code': 'KE',
        'is_active': true,
        'verification_status': 'verified',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });

      expect(provider.name, 'Equity Bank');
      expect(provider.providerType, FinancialPartnerType.bank);
      expect(provider.verificationStatus, FinancingVerificationStatus.verified);
      expect(provider.isActive, isTrue);
      expect(provider.contactEmail, isNull);
      expect(provider.contactPhone, isNull);
      expect(provider.verifiedAt, isNull);
    });

    test('product keeps only public columns and lifecycle stays null', () {
      final product = FinancingProduct.fromMap(const {
        'id': 'pr1',
        'provider_id': 'p1',
        'slug': 'seasonal-input-loan',
        'name': 'Seasonal input loan',
        'product_type': 'input_financing',
        'summary': 'Inputs before planting',
        'description': null,
        'currency': 'KES',
        'min_amount': 5000,
        'max_amount': 250000,
        'interest_rate': 12.5,
        'interest_rate_type': 'reducing_balance',
        'min_tenure_days': 30,
        'max_tenure_days': 365,
        'requires_collateral': false,
        'requirements': ['National ID'],
        'is_active': true,
        'is_published': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });

      expect(product.approvalStatus, isNull,
          reason: 'approval_status is not on the public view');
      expect(product.isPublished, isTrue);
      expect(product.amountRangeLabel, '5,000 – 250,000');
      expect(product.interestLabel, '12.5% Reducing balance');
      expect(product.requirements, ['National ID']);
    });

    test('unknown enum values degrade instead of throwing', () {
      final provider = FinancingProvider.fromMap(const {
        'id': 'p2',
        'slug': 'x',
        'name': 'X',
        'provider_type': 'future_type',
        'is_active': false,
        'verification_status': 'something_new',
      });
      expect(provider.providerType, FinancialPartnerType.bank);
      expect(provider.verificationStatus, FinancingVerificationStatus.pending);
      expect(provider.isActive, isFalse);
    });
  });

  group('Product card rendering', () {
    testWidgets('browse card does not show lifecycle chips', (tester) async {
      const product = FinancingProduct(
        id: 'pr1',
        providerId: 'p1',
        slug: 'loan',
        name: 'Input loan',
        productType: FinancingProductType.inputFinancing,
        isActive: true,
        isPublished: true,
        currency: 'KES',
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FinancingProductCardWidget(product: product),
        ),
      ));

      expect(find.text('Input loan'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Draft'), findsNothing);
      expect(find.text('Approved'), findsNothing);
      expect(find.text('Unpublished'), findsNothing);
    });

    testWidgets('management card shows approval and publication state',
        (tester) async {
      const product = FinancingProduct(
        id: 'pr2',
        providerId: 'p1',
        slug: 'loan',
        name: 'Input loan',
        productType: FinancingProductType.loan,
        isActive: true,
        isPublished: false,
        approvalStatus: FinancingApprovalStatus.inReview,
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FinancingProductCardWidget(
            product: product,
            showLifecycle: true,
          ),
        ),
      ));

      expect(find.text('In review'), findsOneWidget);
      expect(find.text('Unpublished'), findsOneWidget);
    });

    testWidgets('status chip renders the tone it is given', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FinancingStatusChip(label: 'Verified'),
        ),
      ));
      expect(find.text('Verified'), findsOneWidget);
    });
  });
}
