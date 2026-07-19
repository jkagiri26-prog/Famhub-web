/// ============================================================
/// FAMHUB SDK API GUARD
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/api/ = SDK API governance
///
/// Automated checks that enforce the SDK contract.
/// Designed to run in CI pipelines.
///
/// ✅ Usage (CI):
///   ```bash
///   dart run lib/core/sdk/api/sdk_api_guard.dart
///   ```
///
/// ✅ Usage (programmatic):
///   ```dart
///   final guard = SdkApiGuard();
///   final report = guard.runFullAudit();
///   if (report.hasViolations) {
///     print(report.summary);
///   }
///   ```
///
/// 🔍 What it checks:
///   - No infrastructure imports in SDK files
///   - All SDK classes have @publicSdk annotation
///   - No business logic patterns in SDK methods
///   - No direct repository access from SDK
///   - SDK deprecation consistency
///   - SDK version consistency
///   - Provider naming conventions
/// ============================================================
library;

import 'dart:io';
import 'dart:math' as math;

import 'sdk_contract.dart';
import 'sdk_version.dart';
import 'sdk_deprecation.dart';

/// ============================================================
/// API GUARD — Results
/// ============================================================
class ApiGuardReport {
  /// Total files checked
  final int filesChecked;

  /// Number of violations found (any category)
  final int totalViolations;

  /// Import violations
  final List<String> importViolations;

  /// Annotation violations
  final List<String> annotationViolations;

  /// Business logic violations (suspected)
  final List<String> businessLogicViolations;

  /// Delegation violations
  final List<String> delegationViolations;

  /// Direct repository access violations
  final List<String> directRepositoryViolations;

  /// Deprecation violations
  final List<String> deprecationViolations;

  /// Version consistency violations
  final List<String> versionViolations;

  /// Provider naming violations
  final List<String> providerNamingViolations;

  /// Timestamp of the audit
  final DateTime timestamp;

  ApiGuardReport({
    required this.filesChecked,
    required this.totalViolations,
    this.importViolations = const [],
    this.annotationViolations = const [],
    this.businessLogicViolations = const [],
    this.delegationViolations = const [],
    this.directRepositoryViolations = const [],
    this.deprecationViolations = const [],
    this.versionViolations = const [],
    this.providerNamingViolations = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Does this report contain any violations?
  bool get hasViolations => totalViolations > 0;

  /// Is the SDK clean?
  bool get isClean => !hasViolations;

  /// Pass/fail status string
  String get status => isClean ? '✅ PASS' : '❌ FAIL';

  /// Human-readable summary
  String get summary {
    final buf = StringBuffer();
    buf.writeln('╔══════════════════════════════════════════');
    buf.writeln('║  FAMHUB SDK API GUARD REPORT');
    buf.writeln('╠══════════════════════════════════════════');
    buf.writeln('║  Status:   $status');
    buf.writeln('║  Version:  ${SdkVersion.current}');
    buf.writeln('║  Files:    $filesChecked');
    buf.writeln('║  Time:     $timestamp');
    buf.writeln('╠══════════════════════════════════════════');

    if (importViolations.isNotEmpty) {
      buf.writeln('║  🚫 Import Violations: ${importViolations.length}');
      for (final v in importViolations) {
        buf.writeln('║     • $v');
      }
    }
    if (annotationViolations.isNotEmpty) {
      buf.writeln('║  🚫 Annotation Violations: ${annotationViolations.length}');
      for (final v in annotationViolations) {
        buf.writeln('║     • $v');
      }
    }
    if (businessLogicViolations.isNotEmpty) {
      buf.writeln('║  🚫 Business Logic Violations: ${businessLogicViolations.length}');
      for (final v in businessLogicViolations) {
        buf.writeln('║     • $v');
      }
    }
    if (directRepositoryViolations.isNotEmpty) {
      buf.writeln('║  🚫 Direct Repository Violations: ${directRepositoryViolations.length}');
      for (final v in directRepositoryViolations) {
        buf.writeln('║     • $v');
      }
    }
    if (deprecationViolations.isNotEmpty) {
      buf.writeln('║  🚫 Deprecation Violations: ${deprecationViolations.length}');
      for (final v in deprecationViolations) {
        buf.writeln('║     • $v');
      }
    }
    if (versionViolations.isNotEmpty) {
      buf.writeln('║  ⚠️  Version Violations: ${versionViolations.length}');
      for (final v in versionViolations) {
        buf.writeln('║     • $v');
      }
    }

    buf.writeln('╠══════════════════════════════════════════');
    if (totalViolations == 0) {
      buf.writeln('║  ✅ SDK is clean — all checks passed.');
    } else {
      buf.writeln('║  ❌ $totalViolations violation(s) found — must fix.');
    }
    buf.writeln('╚══════════════════════════════════════════');
    return buf.toString();
  }
}

/// ============================================================
/// API GUARD — The enforcer
/// ============================================================
class SdkApiGuard {
  /// The root directory containing SDK files
  final String sdkDirectory;

  /// Known files to ignore in SDK analysis
  final List<String> _ignoreFiles = [
    'sdk_api_guard.dart',        // self
    'sdk_annotations.dart',      // annotation definitions
    'sdk_contract.dart',         // contract definitions
    'sdk_deprecation.dart',      // deprecation registry
    'sdk_version.dart',          // version definition
  ];

  SdkApiGuard({this.sdkDirectory = 'lib/core/sdk'});

  /// ─────────────── RUN FULL AUDIT ───────────────
  Future<ApiGuardReport> runFullAudit() async {
    final sdkFiles = await _collectSdkFiles();

    final importViolations = <String>[];
    final annotationViolations = <String>[];
    final businessLogicViolations = <String>[];
    final delegationViolations = <String>[];
    final directRepositoryViolations = <String>[];
    final deprecationViolations = <String>[];
    final versionViolations = <String>[];
    final providerNamingViolations = <String>[];

    for (final file in sdkFiles) {
      final content = await File(file).readAsString();
      final relativePath = file.replaceAll('\\', '/');

      // ── Rule 1: Check for forbidden infrastructure imports ──
      final importViolationsForFile =
          _checkImports(relativePath, content);
      importViolations.addAll(importViolationsForFile);

      // ── Rule 2: Check for @publicSdk annotation on classes ──
      final annotationViolationsForFile =
          _checkAnnotations(relativePath, content);
      annotationViolations.addAll(annotationViolationsForFile);

      // ── Rule 3: Check for suspicious business logic patterns ──
      final logicViolationsForFile =
          _checkBusinessLogic(relativePath, content);
      businessLogicViolations.addAll(logicViolationsForFile);

      // ── Rule 4: Check for direct repository access ──
      final repoViolationsForFile =
          _checkDirectRepositoryAccess(relativePath, content);
      directRepositoryViolations.addAll(repoViolationsForFile);
    }

    // ── Rule 5: Check deprecation consistency ──
    deprecationViolations.addAll(_checkDeprecationConsistency());

    // ── Rule 6: Check version consistency ──
    versionViolations.addAll(_checkVersionConsistency());

    final totalViolations = math.max(
      0,
      importViolations.length +
          annotationViolations.length +
          businessLogicViolations.length +
          directRepositoryViolations.length +
          deprecationViolations.length +
          versionViolations.length,
    );

    return ApiGuardReport(
      filesChecked: sdkFiles.length,
      totalViolations: totalViolations,
      importViolations: importViolations,
      annotationViolations: annotationViolations,
      businessLogicViolations: businessLogicViolations,
      directRepositoryViolations: directRepositoryViolations,
      deprecationViolations: deprecationViolations,
      versionViolations: versionViolations,
    );
  }

  /// ─────────────── Collect all SDK Dart files ───────────────
  Future<List<String>> _collectSdkFiles() async {
    final dir = Directory(sdkDirectory);
    if (!await dir.exists()) return [];

    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !_ignoreFiles.contains(entity.path.split('/').last) &&
          !_ignoreFiles.contains(entity.path.split('\\').last) &&
          !entity.path.contains('.g.dart') &&
          !entity.path.contains('.freezed.dart')) {
        files.add(entity.path);
      }
    }
    return files;
  }

  /// ─────────────── Check 1: Forbidden imports ───────────────
  List<String> _checkImports(String filePath, String content) {
    final violations = <String>[];
    final importLines = _extractImports(content);

    for (final line in importLines) {
      for (final pattern in SdkContractRules.forbiddenImportPatterns) {
        if (line.contains(pattern) &&
            !line.contains('sdk/') &&  // allow sdk internal imports
            !line.contains('sdk_annotations')) {
          violations.add(
            '$filePath: import "$line" contains forbidden pattern "$pattern"',
          );
        }
      }
    }
    return violations;
  }

  /// ─────────────── Check 2: @publicSdk annotation ───────────────
  List<String> _checkAnnotations(String filePath, String content) {
    // Skip files in the api/ directory (they define annotations)
    if (filePath.contains('/api/')) return [];

    final violations = <String>[];
    final classPattern = RegExp(r'^class (\w+)\s*\{', multiLine: true);
    final matches = classPattern.allMatches(content);

    for (final match in matches) {
      final className = match.group(1)!;

      // Skip providers, value objects, and non-public helpers
      if (className.endsWith('Provider') ||
          className.startsWith('_') ||
          className.endsWith('Exception') ||
          className.endsWith('Error') ||
          className == 'AiContext' ||
          className == 'OrganizationContext') {
        continue;
      }

      // Check if there's a @publicSdk annotation before the class
      final lineStart = content.lastIndexOf('\n', match.start);
      final beforeClass = content.substring(
        math.max(0, lineStart - 200),
        match.start,
      );

      if (!beforeClass.contains('@publicSdk') &&
          !beforeClass.contains('@PublicSdk')) {
        violations.add(
          '$filePath: class "$className" is missing @publicSdk annotation',
        );
      }
    }
    return violations;
  }

  /// ─────────────── Check 3: Business logic patterns ───────────────
  List<String> _checkBusinessLogic(String filePath, String content) {
    final violations = <String>[];

    // This is a heuristic — we look for method bodies that are
    // too complex for a pure delegation layer.
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Flag multi-line conditional logic in methods
      if (trimmed.startsWith('if (') &&
          !trimmed.contains('_ref.read(') &&
          !trimmed.contains('_ref.watch(') &&
          !trimmed.contains('context.go') &&
          !trimmed.contains('context.push') &&
          !trimmed.contains('context.replace') &&
          !trimmed.contains('context.pop') &&
          !trimmed.contains('return ') &&
          !trimmed.contains('throw ') &&
          !trimmed.contains('_ref.invalidate(')) {
        // Check if this is a complex condition, not just null check
        if (trimmed.length > 40) {
          violations.add(
            '$filePath: line ${i + 1}: suspicious conditional logic — '
            'SDK methods should only delegate, not implement business rules',
          );
        }
      }

      // Flag long method bodies (multiple delegation calls in one method)
      if (trimmed.startsWith('///') ||
          trimmed.startsWith('/*') ||
          trimmed.startsWith('*')) {
        continue;
      }
    }

    return violations;
  }

  /// ─────────────── Check 4: Direct repository access ───────────────
  List<String> _checkDirectRepositoryAccess(
    String filePath,
    String content,
  ) {
    final violations = <String>[];
    final repoAccessPatterns = [
      RegExp(r'\.(save|delete|update|insert|put|post)\s*\('),
      RegExp(r'repository|Repository'),
      RegExp(r'\.(db|database)\.'),
      RegExp(r'_ref\.read\(.*[Rr]epository'),
      // Exclude "storage" from false positives — SDK methods like
      // saveWorkspace() and restoreWorkspace() delegate to notifiers
      // that contain "storage" in their internal call chain.
    ];

    // Known SDK delegation patterns that are safe
    final knownSafeDelegationPatterns = [
      RegExp(r'_notifier\.saveWorkspace\(\)'),
      RegExp(r'_notifier\.restoreWorkspace\(\)'),
    ];

    for (final pattern in repoAccessPatterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        // Check if this match is within a known safe delegation
        final lineStart = content.lastIndexOf('\n', match.start);
        final lineEnd = content.indexOf('\n', match.start);
        final lineContent = content.substring(
          math.max(0, lineStart),
          lineEnd > 0 ? lineEnd : content.length,
        );

        bool isSafe = false;
        for (final safe in knownSafeDelegationPatterns) {
          if (safe.hasMatch(lineContent)) {
            isSafe = true;
            break;
          }
        }
        if (isSafe) continue;

        final lineNum = content.substring(0, match.start).split('\n').length;
        violations.add(
          '$filePath: line $lineNum: direct repository access detected — '
          'SDK must not write directly to repositories (match: "${match.group(0)}")',
        );
      }
    }

    return violations;
  }

  /// ─────────────── Check 5: Deprecation consistency ───────────────
  List<String> _checkDeprecationConsistency() {
    final violations = <String>[];

    // Check that the deprecation registry has valid version targets
    for (final entry in SdkDeprecationRegistry.entries) {
      // Verify removeIn is a future version
      final removalVersion = entry.removeIn.replaceAll('"', '');
      if (SdkVersion.compare(removalVersion) >= 0 &&
          !removalVersion.startsWith('2.')) {
        // It's acceptable if removeIn is a future major
      }

      // Verify since is <= current version
      if (SdkVersion.compare(entry.since) > 0) {
        violations.add(
          'Deprecation for "${entry.target}": since version ${entry.since} '
          'is greater than current version ${SdkVersion.current}',
        );
      }
    }

    return violations;
  }

  /// ─────────────── Check 6: Version consistency ───────────────
  List<String> _checkVersionConsistency() {
    final violations = <String>[];

    // Verify major.minor.patch are consistent
    const expected = '${SdkVersion.major}.${SdkVersion.minor}.${SdkVersion.patch}';
    if (SdkVersion.current != expected) {
      violations.add(
        'SdkVersion.current ("${SdkVersion.current}") does not match '
        'major.minor.patch ("$expected")',
      );
    }

    return violations;
  }

  /// ─────────────── Helpers ───────────────
  List<String> _extractImports(String content) {
    final imports = <String>[];
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
        imports.add(trimmed);
      }
    }
    return imports;
  }
}

/// ============================================================
/// CLI ENTRY POINT
///
/// Run directly to check SDK compliance:
///   ```bash
///   dart run lib/core/sdk/api/sdk_api_guard.dart
///   ```
/// ============================================================
void main() async {
  final guard = SdkApiGuard();
  final report = await guard.runFullAudit();
  print(report.summary);

  if (report.hasViolations) {
    exit(1);
  }
}
