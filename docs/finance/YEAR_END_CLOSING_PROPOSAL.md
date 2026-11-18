# Proposed Year-End Closing Architecture (Disabled)

This proposal is not implemented and must remain disabled until the decisions in YEAR_END_DECISIONS.md are approved.

## Proposed records

- `finance.financial_year_closings`
  - entity_id
  - financial_year
  - retained_earnings_account_id
  - closing_journal_id
  - status (`draft`, `approved`, `closed`, `reversed`)
  - prepared_by, reviewed_by, approved_by
  - closed_at
  - unique (entity_id, financial_year)
- `finance.opening_balance_links`
  - next_year_closing_id
  - prior_closing_id
  - opening_journal_id
  - unique linkage
- Optional period metadata: `period_type='monthly'`, `financial_year`.

## Proposed closing logic

1. Require all twelve monthly periods for the financial year, except an approved short-year policy.
2. Require every period closed and no draft/unposted journals.
3. Verify posted journals balance.
4. Compute revenue/expense balances from posted journal lines.
5. Create a closing journal against the approved retained earnings account.
6. Post only through the existing journal/posting engine.
7. Record preparer/reviewer/approver and timestamps.
8. Make closing idempotent by unique entity/year and deterministic idempotency key.
9. Never mutate or delete original journals.

## Proposed opening logic

1. Link the new year opening record to the prior closing record.
2. Carry forward asset, liability and equity balances.
3. Include unpaid obligations and referral reward liabilities using the existing subledger/obligation records.
4. Exclude prior-year revenue and expense balances.
5. Post a balanced opening journal dated January 1 through the existing posting engine.
6. Make opening idempotent by unique entity/year/link.
7. Retain traceability to closing and original journals.

## Required account

Finance must approve a retained earnings/equity account before any closing code is activated.

## Reporting

Financial-year-aware P&L, balance sheet, trial balance, opening/closing balances and liability reports should use posted journal lines only, with explicit label for 2026 initial operating period.

Current monthly reporting behavior before year-end close:

- Each report is separated by entity, accounting period and currency. Amounts in different currencies are never combined.
- The Balance Sheet includes a `CURRENT_PERIOD_RESULT` row calculated as posted revenue less posted expenses for the period and currency. This is a reporting presentation only; it is not a retained-earnings account and does not create a closing journal.
- Assets must equal liabilities plus equity, including `CURRENT_PERIOD_RESULT`, for each entity/period/currency group.
- Balance-sheet signs are derived from `account_type`, not `normal_balance`: asset = debit - credit; liability/equity = credit - debit. This supports allowed contra-asset, contra-liability and contra-equity accounts without changing their chart metadata.
- P&L and financial-year revenue/expense presentation is derived from `account_type`: revenue = credit - debit; expense = debit - credit. This preserves the correct sign for contra-revenue and contra-expense accounts.
- Historical reporting includes inactive ledger accounts that have posted activity or balances. Account active status is exposed separately.
- Monthly views include only complete calendar-month periods. Pre-existing non-monthly historical periods are preserved and excluded rather than reclassified.
- The monthly-period constraints remain `NOT VALID`. Validation must not be forced until historical staging/production data has been audited for legitimate non-monthly periods.
- The local historical compatibility test simulates a legacy row by temporarily rebuilding the constraints inside a transaction. It verifies reporting exclusion and preservation, but it does not prove a real pre-00001 migration boundary; a true boundary test requires a disposable database at the pre-00001 migration state or staging data audit.
- Closed periods cannot be reopened through a direct status update. No separate authorized reopen/correction workflow exists in this phase.
- Authenticated reporting is gated by `finance.user_can_read_entity`, a narrowly scoped `SECURITY DEFINER` helper with a pinned search path. The helper requires an active entity membership and an active profile whose `account_status` is `active`; suspended, blocked and inactive profiles are denied. The RLS policies on Finance reporting tables use this helper, so authenticated users do not receive direct `core.entity_members` access. Entity isolation remains enforced by the helper and existing RLS permissions.
- The 2026-specific `initial_operating_2026_nov_dec` label remains a known low-priority limitation. It is intentionally retained for the initial operating period and does not affect calculations.
