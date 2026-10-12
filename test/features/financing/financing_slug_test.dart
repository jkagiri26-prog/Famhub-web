import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/financing/domain/financing_slug.dart';

/// The slug rules are the client half of the database contract:
/// `financing._validate_slug` (22023) + `*_slug_format_check` + `*_slug_key`.
/// These tests lock the derivation and the exact copy the form shows.
void main() {
  group('buildFinancingSlug', () {
    test('lowercases and hyphenates a display name', () {
      expect(buildFinancingSlug('Equity Bank'), 'equity-bank');
      expect(buildFinancingSlug('  Co-operative  Bank  '), 'co-operative-bank');
      expect(buildFinancingSlug('APA Insurance & Savings'), 'apa-insurance-savings');
    });

    test('collapses punctuation runs into a single hyphen', () {
      expect(buildFinancingSlug('A / B  C'), 'a-b-c');
      expect(buildFinancingSlug('Mkulima SACCO — 2026'), 'mkulima-sacco-2026');
    });

    test('strips leading and trailing separators', () {
      expect(buildFinancingSlug('---Equity---'), 'equity');
      expect(buildFinancingSlug('   '), '');
      expect(buildFinancingSlug('!!!'), '');
    });

    test('produces an empty slug when nothing ascii-alphanumeric survives', () {
      expect(buildFinancingSlug('🌱🌾'), '');
      expect(buildFinancingSlug('— — —'), '');
      expect(buildFinancingSlug('   \t\n '), '');
    });
  });

  group('resolveProviderSlug', () {
    test('an explicitly typed slug always wins', () {
      expect(
        resolveProviderSlug(
          name: 'Equity Bank',
          existingSlug: 'old-slug',
          previousName: 'Old Name',
          manualSlug: 'custom-value',
        ),
        'custom-value',
      );
    });

    test('an explicitly cleared slug is passed through for validation', () {
      expect(
        resolveProviderSlug(name: 'Equity Bank', manualSlug: ''),
        '',
      );
    });

    test('creation derives the slug from the name', () {
      expect(resolveProviderSlug(name: 'Equity Bank'), 'equity-bank');
    });

    test('an edit with an unchanged name preserves the stored slug', () {
      expect(
        resolveProviderSlug(
          name: 'Equity Bank',
          existingSlug: 'equity-ke',
          previousName: 'Equity Bank',
          manualSlug: null,
        ),
        'equity-ke',
      );
    });

    test('an edit with a changed name regenerates the slug', () {
      expect(
        resolveProviderSlug(
          name: 'Equity Bank Kenya',
          existingSlug: 'equity-bank',
          previousName: 'Equity Bank',
          manualSlug: null,
        ),
        'equity-bank-kenya',
      );
    });
  });

  group('validateFinancingSlug', () {
    test('accepts the exact database pattern', () {
      expect(validateFinancingSlug('equity-bank', generated: true), isNull);
      expect(validateFinancingSlug('a1-b2-c3', generated: false), isNull);
      expect(validateFinancingSlug('coop2026', generated: true), isNull);
    });

    test('rejects values the CHECK constraint would reject', () {
      expect(
        validateFinancingSlug('Equity Bank', generated: false),
        financingSlugFormatError,
      );
      expect(
        validateFinancingSlug('-leading', generated: false),
        financingSlugFormatError,
      );
      expect(
        validateFinancingSlug('trailing-', generated: false),
        financingSlugFormatError,
      );
      expect(
        validateFinancingSlug('double--hyphen', generated: false),
        financingSlugFormatError,
      );
      expect(
        validateFinancingSlug('kenya_uganda', generated: false),
        financingSlugFormatError,
      );
    });

    test('explains an empty value differently for typed and derived input', () {
      expect(
        validateFinancingSlug('', generated: false),
        financingSlugRequiredError,
      );
      expect(
        validateFinancingSlug('', generated: true),
        financingSlugUnusableError,
      );
    });
  });
}
