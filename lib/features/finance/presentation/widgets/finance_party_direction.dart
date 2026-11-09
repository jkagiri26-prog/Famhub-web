/// ============================================================
/// FINANCE — PARTY DIRECTION
/// ============================================================
///
/// UI-only helper for labelling a Finance row relative to the active entity.
/// This is not an authorization decision: the database RLS has already scoped
/// every row to a party the caller may read.
/// ============================================================
library;

enum FinancePartyDirection { payable, receivable, neutral }

FinancePartyDirection resolveFinancePartyDirection({
  required String? activeEntityId,
  required String payerEntityId,
  required String payeeEntityId,
}) {
  if (activeEntityId == null || activeEntityId.isEmpty) {
    return FinancePartyDirection.neutral;
  }
  if (activeEntityId == payerEntityId) {
    return FinancePartyDirection.payable;
  }
  if (activeEntityId == payeeEntityId) {
    return FinancePartyDirection.receivable;
  }
  return FinancePartyDirection.neutral;
}

String financePartyDirectionLabel(FinancePartyDirection direction) {
  return switch (direction) {
    FinancePartyDirection.payable => 'You owe',
    FinancePartyDirection.receivable => 'Owed to you',
    FinancePartyDirection.neutral => 'Party obligation',
  };
}
