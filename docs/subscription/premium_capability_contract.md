# Premium Capability Contract

Core Vunio functionality is free. Subscriptions unlock optional premium
extensions identified by stable capability keys.

## Canonical rule

A premium feature is identified by one stable capability key, for example:

```text
farm_analytics
```

Plan metadata (`system.subscription_plans.features_json`) and the existing
FeatureRegistry must use the same key. Do not add premium booleans, subscriber
flags, plan-name checks, price checks, billing-frequency checks, or
module-specific subscription providers.

## Flutter

1. Define or reuse the capability key.
2. Add it to the canonical plan metadata.
3. Read entitlement state only through `subscriptionEntitlementsProvider`.
4. Wrap the premium UI with `PremiumCapabilityGate`.
5. Leave core/free UI outside the gate.
6. Use `AppRoutes.subscription` as the upgrade destination.

Missing, loading, error, expired, or capability-less entitlement state fails
closed for the premium feature only.

## Server-side premium operations

Before performing a premium backend operation, verify the caller's capability
using the existing canonical resolver:

```sql
select system.assert_subscription_capability('farm_analytics');
```

or the non-throwing form:

```sql
select system.has_subscription_capability('farm_analytics');
```

Pass the authenticated caller JWT to the RPC or Edge Function. UI visibility is
not the security boundary. Do not add premium checks to ordinary free Farm RLS
or data reads.

## Reference implementation

`farm_analytics` gates `FarmRecommendationsWidget` through
`FarmPremiumInsightsGate`, which delegates to the reusable
`PremiumCapabilityGate`. Core Farm Management remains free.
