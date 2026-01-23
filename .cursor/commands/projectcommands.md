# projectcommands

# PROJECT COMMANDS – AGRITECH PLATFORM

## 1. CREATE_SCREEN
Command:
- Create a new Flutter screen in the project
- Accepts: screen_name, module_name
- Must follow:
  - File: underscore_case (e.g., crop_detail_screen.dart)
  - Class: PascalCase
  - StatelessWidget preferred
- Include basic UI scaffold and AppBar
- Include Riverpod state placeholder if needed
- Explain each part in simple terms
- Add comment TODOs for future functionality

Example usage:
> CREATE_SCREEN: screen_name=crop_log, module_name=farmer_dashboard

---

## 2. ADD_RIVERPOD_PROVIDER
Command:
- Add a new Riverpod provider
- Accepts: provider_name, type (StateNotifier / AsyncNotifier / etc.)
- Must follow naming conventions (camelCase)
- Include try-catch if it calls database
- Explain the provider in beginner-friendly terms

Example usage:
> ADD_RIVERPOD_PROVIDER: provider_name=cropLogProvider, type=StateNotifier

---

## 3. CREATE_SUPABASE_SERVICE
Command:
- Generate a service class for Supabase queries
- Accepts: table_name, module_name, operations (CRUD)
- Include basic error handling (try-catch)
- Explain each method simply
- Follow snake_case for database columns

Example usage:
> CREATE_SUPABASE_SERVICE: table_name=crops, module_name=farmer_dashboard, operations=create,read,update

---

## 4. EXPLAIN_CODE
Command:
- Explain any code snippet I provide
- Break explanation into small steps
- Describe what each line or block does
- Highlight potential risks or common mistakes

Example usage:
> EXPLAIN_CODE: [paste code snippet here]

---

## 5. ADD_MODULE_FEATURE
Command:
- Add a new feature inside an existing module
- Accepts: feature_name, module_name
- Must respect SYSTEM_OVERVIEW.md rules
- Provide a brief explanation of purpose and how it fits
- Include placeholders for UI + Riverpod + Supabase if applicable

Example usage:
> ADD_MODULE_FEATURE: feature_name=weather_alerts, module_name=weather_climate

---

## 6. FIX_ERROR
Command:
- Suggest a fix for an error in code
- Must explain the cause simply
- Provide corrected code
- Warn if fix affects other modules or tables

Example usage:
> FIX_ERROR: [paste error message or code snippet here]

---

## 7. GENERATE_REPORT_SCREEN
Command:
- Create a screen that shows data reports for farmers
- Accepts: report_type (profit, expenses, yield), module_name
- Include basic charts/tables (simple, low-data)
- Explain what each part displays

Example usage:
> GENERATE_REPORT_SCREEN: report_type=profit, module_name=farmer_dashboard


This command will be available in chat with /projectcommands
