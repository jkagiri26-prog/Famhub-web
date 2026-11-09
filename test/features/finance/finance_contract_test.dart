import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment_attempt.dart';
import 'package:famhub_app/features/finance/infrastructure/data_sources/finance_remote_data_source.dart';

/// Contract assertions against the deployed Finance read surface.
///
/// These are static/source-level checks only. No Supabase connection is made.
void main() {
  // Access-layer contract: presentation widgets may use local Map.update(),
  // which is not a database write. Only the infrastructure layer is scanned.
  final root = Directory('lib/features/finance/infrastructure');
  final dartFiles =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String stripComments(String source) {
    final noBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    final buffer = StringBuffer();
    for (final line in noBlock.split('\n')) {
      final index = line.indexOf('//');
      buffer.writeln(index < 0 ? line : line.substring(0, index));
    }
    return buffer.toString();
  }

  group('Finance read source stays read-only', () {
    test('no direct insert / update / upsert / delete calls exist', () {
      final offenders = <String>[];

      for (final file in dartFiles) {
        final source = stripComments(file.readAsStringSync());
        for (final forbidden in <String>[
          '.insert(',
          '.update(',
          '.upsert(',
          '.delete(',
        ]) {
          if (source.contains(forbidden)) {
            offenders.add('${file.path} → $forbidden');
          }
        }
      }

      expect(offenders, isEmpty);
    });

    test('no wildcard select is used', () {
      final wildcard = RegExp(r'''\.select\(\s*['"]\*['"]\s*\)''');
      final offenders = dartFiles
          .where(
            (file) => wildcard.hasMatch(stripComments(file.readAsStringSync())),
          )
          .map((file) => file.path)
          .toList();

      expect(offenders, isEmpty);
    });

    test('forbidden Finance tables are never queried directly', () {
      final forbiddenTables = <String>[
        'obligation_settlements',
        'payment_attempts',
        'provider_events',
        'payments',
        'payment_methods',
      ];
      final offenders = <String>[];

      for (final file in dartFiles) {
        final source = stripComments(file.readAsStringSync());
        for (final table in forbiddenTables) {
          final pattern = RegExp(
            '''\\.from\\(\\s*['"]${RegExp.escape(table)}['"]\\s*\\)''',
          );
          if (pattern.hasMatch(source)) {
            offenders.add('${file.path} → $table');
          }
        }
      }

      expect(offenders, isEmpty);
    });

    test('only the intended Finance views are read from', () {
      const allowed = {
        'v_obligation_balances',
        'v_obligation_settlement_history',
        'v_verified_payment_collections',
      };
      final tablePattern = RegExp(r'''\.from\(\s*['"]([^'"]+)['"]''');
      final offenders = <String>[];

      for (final file in dartFiles) {
        final source = stripComments(file.readAsStringSync());
        for (final match in tablePattern.allMatches(source)) {
          final table = match.group(1)!;
          if (!allowed.contains(table)) {
            offenders.add('${file.path} → $table');
          }
        }
      }

      expect(offenders, isEmpty);
    });

    test('no service-role client or service-role reference exists', () {
      final pattern = RegExp(r'service[_-]?role', caseSensitive: false);
      final offenders = dartFiles
          .where(
            (file) => pattern.hasMatch(stripComments(file.readAsStringSync())),
          )
          .map((file) => file.path)
          .toList();

      expect(offenders, isEmpty);
    });
  });

  group('Finance column contracts', () {
    const obligationColumns = [
      'obligation_id',
      'payer_entity_id',
      'payee_entity_id',
      'commercial_order_id',
      'legacy_order_id',
      'obligation_type',
      'obligation_status',
      'currency',
      'obligation_amount',
      'total_settlements',
      'outstanding_balance',
      'settlement_count',
      'due_at',
      'created_at',
      'updated_at',
    ];
    const settlementColumns = [
      'id',
      'obligation_id',
      'payment_id',
      'currency',
      'amount',
      'settled_at',
    ];
    const paymentColumns = [
      'payment_id',
      'provider',
      'provider_reference',
      'amount',
      'currency',
      'payer_entity_id',
      'payee_entity_id',
      'verified_at',
      'created_at',
      'collection_record_status',
      'bank_settlement_status',
    ];

    List<String> splitColumns(String value) {
      return value
          .split(',')
          .map((column) => column.trim())
          .where((column) => column.isNotEmpty)
          .toList();
    }

    test('obligation balance selection matches v_obligation_balances', () {
      expect(splitColumns(FinanceColumns.obligationBalance), obligationColumns);
    });

    test('settlement selection matches v_obligation_settlement_history', () {
      expect(splitColumns(FinanceColumns.settlementHistory), settlementColumns);
    });

    test('payment selection matches v_verified_payment_collections', () {
      expect(splitColumns(FinanceColumns.verifiedPayment), paymentColumns);
    });

    test('protected fields are never selected', () {
      final selected = <String>[
        ...splitColumns(FinanceColumns.obligationBalance),
        ...splitColumns(FinanceColumns.settlementHistory),
        ...splitColumns(FinanceColumns.verifiedPayment),
      ];

      for (final forbidden in <String>[
        'metadata',
        'idempotency_key',
        'provider_token_ref',
        'display_details',
        'verification_metadata',
        'provider_request_ref',
        'failure_code',
        'failure_message',
        'payload',
        'provider_query_result',
      ]) {
        expect(selected, isNot(contains(forbidden)));
      }
    });

    test('RPC names and parameters match the deployed status function', () {
      expect(
        FinanceRpcNames.getPaymentAttemptStatus,
        'get_payment_attempt_status',
      );
      expect(FinanceRpcParams.paymentAttemptId, 'p_payment_attempt_id');
    });
  });

  group('Finance enum contracts', () {
    test('obligation type values match the SQL CHECK constraint', () {
      expect(FinanceObligationType.values.map((type) => type.dbValue).toSet(), {
        'order',
        'subscription',
        'fee',
        'payout',
        'refund',
        'other',
      });
    });

    test('obligation status values match the SQL CHECK constraint', () {
      expect(
        FinanceObligationStatus.values.map((status) => status.dbValue).toSet(),
        {'draft', 'open', 'partially_settled', 'settled', 'cancelled', 'void'},
      );
    });

    test('payment attempt status values match the SQL CHECK constraint', () {
      expect(
        FinancePaymentAttemptStatus.values
            .map((status) => status.dbValue)
            .toSet(),
        {
          'created',
          'pending',
          'processing',
          'succeeded',
          'failed',
          'cancelled',
          'expired',
        },
      );
    });
  });
}
