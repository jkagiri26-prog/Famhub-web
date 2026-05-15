# PROJECT CONTEXT: Farming Platform (AgTech)
- **App Name:** [Famhub]
- **Tech Stack:** Flutter (Dart), Supabase (PostgreSQL).
- **User Persona:** Farmers and Agricultural Buyers. Some users may have low digital literacy.

# DEVELOPMENT GOALS (STRATEGIC)
1. **Performance:** Prioritize speed and low-data usage for rural areas.
2. **UI Style:** Use high-contrast, large touch targets (buttons). Farmers may use this in direct sunlight.
3. **Security:** Use Supabase Row Level Security (RLS) strictly. Users must only see their own data.
4. **Offline First:** Design logic that allows data entry without internet, to be synced later.

# CODE STYLE & RULES
- **State Management:** Use Riverpod (v2.x) for all state management.
- **Database:** Always use the latest `supabase_flutter` SDK patterns.
- **Widgets:** Prefer `StatelessWidget` and use `const` constructors wherever possible for performance.
- **Navigation:** Use `go_router` for clean, deep-linkable navigation.
- **Naming:** - Variables: camelCase
  - Files: underscore_case (e.g., crop_detail_screen.dart)
  - Database Columns: snake_case (e.g., harvest_date)

# GUIDELINES
- DO NOT use deprecated Supabase Auth patterns.
- If a task is complex, break it into smaller steps before writing code.
- Always include basic error handling (try-catch) for database calls.r