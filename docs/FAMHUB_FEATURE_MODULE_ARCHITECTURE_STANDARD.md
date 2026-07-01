# FAMHUB Official Feature Module Architecture Standard v1.0 (Locked)

## Objective

Effective immediately, all FAMHUB feature modules shall follow one standardized enterprise architecture regardless of module size.

The goal is:
- predictable project structure
- easier maintenance
- consistent code generation
- simpler onboarding
- scalable enterprise architecture

This standard applies to every feature including:
- Farm Management
- Marketplace
- Finance
- Knowledge Link
- Traceability
- Extension Services
- Agribusiness
- Carbon Credit
- Analytics
- Opportunities
- Referral Hub
- Home
- Search
- Notifications
- AI Assistant
- Reports
- Future modules

---

## Official Feature Structure

```
features/
└── module_name/
    ├── application/
    │   ├── ai/
    │   ├── controllers/
    │   ├── providers/
    │   ├── state/
    │   └── usecases/
    ├── domain/
    │   ├── entities/
    │   ├── models/
    │   ├── value_objects/
    │   ├── enums/
    │   ├── repositories/
    │   └── services/
    ├── infrastructure/
    │   ├── data_sources/
    │   ├── repositories/
    │   └── services/
    ├── presentation/
    │   ├── pages/
    │   └── widgets/
    ├── module/
    └── config/
```

---

## Domain Layer Rules

### `entities/`
Contains business entities with identity.

**Examples:**

| Module | Entities |
|--------|----------|
| Farm Management | Farm, Field, Crop, Livestock, Asset |
| Marketplace | Listing, Order, Review, Seller, Product |
| Finance | Loan, Wallet, Invoice, Transaction |

### `models/`
Contains non-domain business models.
These are **NOT** business entities.

**Examples:**
- ListingFilterModel
- FarmStatisticsModel
- CategoryModel
- DashboardSummaryModel
- MarketplaceSearchModel
- Filter models
- Statistics models
- Search models
- Configuration models
- DTOs
- Aggregation models
- Summary models
- View models

### `value_objects/`
Contains immutable business concepts.

**Examples:**
- Money
- Price
- Quantity
- Weight
- Rating
- PhoneNumber
- Location
- GeoCoordinate
- Percentage

### `enums/`
Contains all module enums.

**Examples:**
- ListingStatus
- OrderStatus
- CropStatus
- PaymentStatus
- LoanStatus
- VerificationStatus

### `repositories/`
Contains **ONLY** abstract contracts.

**Example:**
```dart
abstract class MarketplaceRepository {}
```

> No implementation is allowed here.

### `services/`
Contains pure domain services only.
Business rules that don't naturally belong to a single entity.

---

## Infrastructure Layer Rules

Infrastructure contains **implementations only**.

### `data_sources/`
Responsible for:
- Supabase
- REST
- Local DB
- Cache
- Offline

### `repositories/`
Contains repository implementations.

**Example:**
- `MarketplaceRepositoryImpl` implements `MarketplaceRepository`

### `services/`
Contains:
- mappers
- adapters
- external integrations
- utility services

**Examples:**
- `ListingMapper`
- `MarketplaceService`
- `SyncService`

---

## Application Layer Rules

Contains **orchestration only**.
- No UI.
- No Supabase.
- No Widgets.

Contains:
- `controllers/`
- `providers/`
- `state/`
- `usecases/`
- `ai/`

### `state/`
Contains module state classes.

**Examples:**
- `MarketplaceState`
- `FarmState`
- `FinanceState`

### `usecases/`
Contains business use cases.

**Examples:**
- `CreateListing`
- `UpdateListing`
- `DeleteListing`
- `PublishListing`
- `ApproveLoan`
- `HarvestCrop`

---

## Presentation Layer

Contains **only UI**.
- `pages/`
- `widgets/`

> No business logic.
> No direct Supabase.
> Everything comes through Providers or Use Cases.

---

## Module Layer

Contains:
- `module.dart`
- `runtime_descriptor.dart`
- `widget_registration.dart`

Responsible for runtime registration only.

---

## Config Layer

Contains:
- `permissions.dart`
- `constants.dart`
- feature configuration

> No logic.

---

## Enterprise Rules

### Complete Folder Structure Mandate
Every feature **MUST** contain the complete folder structure even if some folders are temporarily empty.

**Example:**
```
models/
value_objects/
state/
usecases/
```
may initially be empty.
This is intentional.
It guarantees architectural consistency.

### Repository Rule
Always use:
```
Domain     → Repository (abstract)
                ↓
Infrastructure → RepositoryImpl
                ↓
Data Source
                ↓
Supabase
```

> Never allow Providers or UI to talk directly to Supabase.

---

## Dashboard Engine Exception

Dashboard Engine is **not** a business feature.
It is an infrastructure/runtime engine.

Therefore:
- `domain/models/` is its primary domain.
- It does **not** require business entities.

> This exception also applies to other future runtime engines.

---

## Migration Rule

While aligning existing modules:

1. **DO NOT** rebuild working code.
2. **DO NOT** duplicate functionality.
3. Prefer **moving** existing files into the correct folders.
4. Prefer **ALTER/refactor** over rewrite.
5. **Preserve APIs** where possible.
6. **Maintain backward compatibility** throughout the migration.

---

## FAMHUB Architecture Status

This structure is now the **official enterprise feature architecture** for FAMHUB.

All future modules, refactoring, AI-generated code, and architecture reviews **must conform** to this standard unless an explicit architectural exception (such as a runtime engine) has been approved.
