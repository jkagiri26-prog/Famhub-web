/// ============================================================
/// FAMHUB SDK CONTRACT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/api/ = SDK API governance
///
/// This file defines the CONTRACT that every SDK class must follow.
/// It is both documentation AND a runtime-verifiable specification.
///
/// 🔒 THE RULES:
///   1.  SDK classes are facades — they ONLY delegate to internal engines
///   2.  SDK classes do NOT contain business logic
///   3.  SDK classes do NOT write directly to repositories/databases
///   4.  SDK classes do NOT import infrastructure layers
///   5.  SDK classes do NOT expose internal providers directly
///   6.  SDK classes do NOT perform I/O directly
///   7.  SDK methods return primitives or domain value objects only
///   8.  SDK providers must be annotated with @sdkProvider
///   9.  Every SDK public class must be annotated with @publicSdk
///   10. Every SDK method must delegate — not implement logic
///
/// 🚫 VIOLATIONS (will fail CI checks):
///   - Importing a repository from the SDK
///   - Importing an infrastructure class from the SDK
///   - Reading/writing to databases from the SDK
///   - Implementing conditional business logic in the SDK
///   - Exposing a ProviderRef directly (use facade pattern)
/// ============================================================
library;

/// ============================================================
/// THE SDK CONTRACT
///
/// Every SDK class implicitly signs this contract.
/// It defines what the SDK IS and what it IS NOT.
/// ============================================================
abstract class SdkContract {
  /// The SDK implementation MUST delegate to internal engines/providers.
  /// It MUST NOT contain business logic.
  ///
  /// ✅ CORRECT:
  ///   ```dart
  ///   bool has(Object capability) =>
  ///       _ref.read(hasCapabilityProvider(capability));
  ///   ```
  ///
  /// ❌ WRONG:
  ///   ```dart
  ///   bool has(Object capability) {
  ///     final user = _ref.read(userProvider);
  ///     if (user.role == 'admin') return true;  // ← BUSINESS LOGIC
  ///     return _ref.read(hasCapabilityProvider(capability));
  ///   }
  ///   ```
  void validateNoBusinessLogic();

  /// The SDK MUST NOT import infrastructure, data, or repository layers.
  ///
  /// ✅ ALLOWED imports:
  ///   - core/sdk/*
  ///   - core/*/application/* (providers)
  ///   - core/*/domain/* (value objects)
  ///   - package:flutter_riverpod
  ///   - package:flutter/widgets (for BuildContext only)
  ///
  /// ❌ FORBIDDEN imports:
  ///   - core/*/infrastructure/*
  ///   - core/*/data/*
  ///   - data/*
  ///   - Any direct database/storage access
  void validateNoInfrastructureImports();

  /// The SDK MUST NOT write directly to any repository or database.
  ///
  /// ✅ CORRECT:
  ///   ```dart
  ///   Future<void> switchOrganization(String id) async {
  ///     await _ref.read(orgProvider.notifier).switchOrg(id);  // delegates
  ///   }
  ///   ```
  ///
  /// ❌ WRONG:
  ///   ```dart
  ///   Future<void> switchOrganization(String id) async {
  ///     final repo = _ref.read(orgRepositoryProvider);       // ← DIRECT REPO
  ///     await repo.save(Organization(id: id));
  ///   }
  ///   ```
  void validateNoDirectRepositoryAccess();

  /// The SDK MUST NOT contain UI, rendering, or widget code.
  ///
  /// ✅ CORRECT:
  ///   ```dart
  ///   void go(BuildContext context, String route) => context.go(route);
  ///   ```
  ///
  /// ❌ WRONG:
  ///   ```dart
  ///   Widget buildModuleButton(String key) => ElevatedButton(...);  // ← UI
  ///   ```
  void validateNoUiCode();
}

/// ============================================================
/// SDK CONTRACT ENFORCEMENT RULES
///
/// These rules are designed for CI automation.
/// They can be checked by parsing the SDK source files.
/// ============================================================
class SdkContractRules {
  /// ──────── Rule 1: No infrastructure imports ────────
  ///
  /// SDK files must NOT import from:
  ///   - core/*/infrastructure/
  ///   - data/
  ///   - Any path containing 'repository' or 'storage'
  static const List<String> forbiddenImportPatterns = [
    'infrastructure',
    'repository',
    'repositories',
    'storage',
    'database',
    'data/',
  ];

  /// ──────── Rule 2: No business logic patterns ────────
  ///
  /// SDK methods must not contain:
  ///   - if/else blocks that implement domain decisions
  ///   - switch statements with domain logic
  ///   - Loops that implement domain algorithms
  ///   - Direct instantiation of domain entities
  ///
  /// This cannot be 100% automated — it requires code review.
  /// But CI can flag suspicious patterns.
  static const List<String> suspiciousPatterns = [
    'if (',
    'switch (',
    'for (',
    'while (',
    'repository',
    '.save(',
    '.delete(',
    '.update(',
    '.insert(',
  ];

  /// ──────── Rule 3: Pure delegation pattern ────────
  ///
  /// Every SDK method should be a one-liner that delegates.
  /// Multi-line methods are suspect.
  static const int maxMethodLines = 5;

  /// ──────── Rule 4: Annotation required ────────
  ///
  /// Every class in the SDK directory MUST have @publicSdk
  static const bool requirePublicSdkAnnotation = true;

  /// ──────── Rule 5: No direct Ref.watch in constructors ────────
  ///
  /// SDK classes should store Ref and delegate in methods,
  /// not watch providers in constructors.
  static const bool forbidWatchInConstructor = true;

  /// Validate a given set of imports against the contract
  static List<String> validateImports(List<String> imports) {
    final violations = <String>[];
    for (final import in imports) {
      for (final pattern in forbiddenImportPatterns) {
        if (import.contains(pattern)) {
          violations.add(
            'Import "$import" contains forbidden pattern "$pattern"',
          );
        }
      }
    }
    return violations;
  }
}
