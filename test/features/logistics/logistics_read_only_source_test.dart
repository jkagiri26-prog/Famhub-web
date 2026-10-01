import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/logistics/infrastructure/data_sources/logistics_rpc_gateway.dart';

/// ============================================================
/// READ-ONLY SOURCE SCAN
///
/// The Logistics feature must never write a table directly. Every write
/// goes through the confirmed backend RPCs; `logistics.tracking_sessions.status`
/// is never UPDATEd and `logistics.location_points` is never INSERTed.
/// ============================================================
void main() {
  final root = Directory('lib/features/logistics');
  final dartFiles = root
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

  group('Logistics source stays read-only', () {
    test('the feature directory contains dart sources', () {
      expect(dartFiles, isNotEmpty);
      expect(
        dartFiles.map((f) => f.path),
        contains(
          'lib/features/logistics/infrastructure/data_sources/'
          'logistics_rpc_gateway.dart',
        ),
      );
    });

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

      expect(
        offenders,
        isEmpty,
        reason: 'Writes must go through the confirmed Logistics RPCs:\n'
            '${offenders.join('\n')}',
      );
    });

    test('no raw SQL mutation statements are used', () {
      final sqlMutation = RegExp(
        r'\b(insert\s+into|update\s+\w+\s+set|delete\s+from)\b',
        caseSensitive: false,
      );
      final offenders = <String>[];

      for (final file in dartFiles) {
        final source = stripComments(file.readAsStringSync());
        if (sqlMutation.hasMatch(source)) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'The feature reads through PostgrestFilterBuilder only:\n'
            '${offenders.join('\n')}',
      );
    });

    test('every rpc name literal belongs to the confirmed contract', () {
      const confirmed = {
        'start_tracking_session',
        'pause_tracking_session',
        'resume_tracking_session',
        'complete_tracking_session',
        'record_location_point',
        'assign_transport',
      };

      final literal = RegExp(r"""\.rpc\(\s*'([^']+)'""");
      final offenders = <String>[];

      for (final file in dartFiles) {
        final source = stripComments(file.readAsStringSync());
        for (final match in literal.allMatches(source)) {
          final name = match.group(1)!;
          if (!confirmed.contains(name)) {
            offenders.add('${file.path} → $name');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Only confirmed RPC names may be called:\n'
            '${offenders.join('\n')}',
      );
    });

    test('the RPC gateway declares exactly the confirmed names', () {
      expect(LogisticsRpcNames.startTrackingSession, 'start_tracking_session');
      expect(LogisticsRpcNames.pauseTrackingSession, 'pause_tracking_session');
      expect(LogisticsRpcNames.resumeTrackingSession, 'resume_tracking_session');
      expect(
        LogisticsRpcNames.completeTrackingSession,
        'complete_tracking_session',
      );
      expect(LogisticsRpcNames.recordLocationPoint, 'record_location_point');
      expect(LogisticsRpcNames.assignTransport, 'assign_transport');
    });
  });
}
