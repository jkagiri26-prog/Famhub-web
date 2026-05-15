# 🌾 FAMHUB — MASTER PROJECT DEFINITION

## 1. PROJECT CONTEXT (AgTech)
* **App Name:** Famhub
* **Tech Stack:** Flutter (Dart), Supabase (PostgreSQL), Riverpod (v2.x), GoRouter.
* **User Persona:** Farmers and Agricultural Buyers. 
* **Accessibility:** High-contrast UI, large touch targets (for direct sunlight use), and simplified flows for users with low digital literacy.

## 2. STRATEGIC GOALS
* **Performance:** Low-data usage for rural areas.
* **Security:** Mandatory **Supabase Row Level Security (RLS)**. Users only see their own data.
* **Offline First:** Local data entry via `CacheService` with background sync once internet is restored.
* **Architecture:** Modular, Multi-Platform (Mobile, Tablet, Desktop, Web), and Self-Registering.

## 3. CORE PRINCIPLES
* **Scalability:** Multi-country and multi-organization ready.
* **Isolation:** Modules are independent and lazy-loaded.
* **Low Cost:** Minimal server load and efficient rebuilds.
## 4. PROJECT STRUCTURE
* **lib/main.dart:** Minimal entry point (Initialization only).
* **shared/layout/:** Contains `MainShell` and `DashboardShell`.
* **core/:** Central logic (Providers, Services, Database, Theme).
* **features/module_name/:** Self-contained module logic (Views, Providers, Repositories).
* **system/:** Central Registries (Module, Dashboard, Role, Services).

## 5. THE "NO-SCAFFOLD" RULE
Modules **MUST NOT** contain:
* `Scaffold`, `AppBar`, or `BottomNavigationBar`.
* These are handled exclusively by the **MainShell**.

## 6. PAGE DEVELOPMENT
Every page MUST start with this root structure:
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 600) return _buildMobile();
      if (constraints.maxWidth < 1024) return _buildTablet();
      return _buildDesktop();
    },
  ),
)

### 7. 📂 File Naming
All files must use **underscore_case** (also known as snake_case).
* **Rule:** lowercase with underscores separating words.
* **Examples:**
    * `harvest_report_page.dart`
    * `crop_inventory_repository.dart`
    * `weather_service.dart`
### 🏗️ Class Naming
All classes must use **PascalCase** (UpperCamelCase).
* **Rule:** Start every word with a Capital letter, no spaces or underscores.
* **Examples:**
    * `class HarvestReportPage { ... }`
    * `class CropInventoryProvider { ... }`
    * `class AuthRepository { ... }`
### 🔢 Variable & Method Naming
All variables, functions, and methods must use **camelCase** (lowerCamelCase).
* **Rule:** Start with a lowercase letter; every following word starts with a Capital.
* **Examples:**
    * `final int totalHarvestWeight;`
    * `void fetchUserCrops() { ... }`
    * `String farmerName;`
### 🗄️ Database (Supabase/PostgreSQL)
All table names and column names must use **snake_case**.
* **Rule:** lowercase with underscores (Standard SQL convention).
* **Examples:**
    * **Table:** `farmer_profiles`
    * **Column:** `phone_number`
    * **Column:** `last_sync_at`
### 📋 Quick Reference Table
| Component | Style | Example |
| :--- | :--- | :--- |
| **Folder/File** | `underscore_case` | `lib/features/land_registry/` |
| **Class** | `PascalCase` | `class LandRegistryPage` |
| **Variable** | `camelCase` | `var currentCropIndex = 0;` |
| **DB Column** | `snake_case` | `created_at`, `user_id` |

## 8. AI COLLABORATION GUIDELINES
* **Simplicity:** Explain code simply for non-coders.
* **Step-by-Step:** Break complex features into small milestones.
* **Resilience:** Always include `try-catch` error handling for database calls.
* **Modernity:** Use latest `supabase_flutter` patterns (No deprecated Auth).

## 9. MODULE SUBMISSION STEPS
Every time a module is developed or updated:
1.  **Generate** the full folder structure in `features/`.
2.  **Provide** the Provider (UI State), Repository (Data), and View (Responsive).
3.  **Register** the module in `system/module_registry.dart`.
4.  **Update** `dashboard_registry.dart` and `role_registry.dart`.
5.  **DROP THE FULL UPDATED CODE** for any file affected by the change.

## 10. DATA FLOW
**UI** (StatelessWidget) ➔ **Provider** (Riverpod) ➔ **Repository** (Backend) ➔ **Supabase** (RLS).