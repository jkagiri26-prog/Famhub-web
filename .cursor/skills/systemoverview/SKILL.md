---
name: systemoverview
description: This is a new rule
---
# SYSTEM OVERVIEW – AGRITECH FARMING PLATFORM

This document is the **single source of truth** for system structure, modules, and boundaries.
All AI-assisted development (Cursor) must respect this overview.

---

## 1. PLATFORM PURPOSE

A farmer-first AgTech platform designed for:
- Low bandwidth environments
- Mobile-first usage
- Users with low digital literacy

Primary goals:
- Improve farm management
- Increase farmer income
- Reduce inefficiencies in selling, logistics, and planning
- Introduce modern features without complexity

Clarity and usability are more important than technical sophistication.

---

## 2. TARGET USERS

- Farmers (primary users)
- Agricultural buyers
- Service providers (logistics, inputs, tools)
- Extension and knowledge providers

---

## 3. TECHNOLOGY STACK

- Frontend: Flutter (Dart)
- Backend: Supabase
  - PostgreSQL
  - Auth
  - Storage
- State Management: Riverpod v2.x
- Navigation: go_router

---

## 4. CORE DESIGN PRINCIPLES

- Farmer-first UX
- High contrast, large touch targets
- Simple language (no tech jargon)
- Offline-first mindset
- Modular system design
- Strong data ownership & security (RLS)

---

## 5. SYSTEM MODULES (AUTHORITATIVE MAP)

### 5.1 Farmer Dashboard (CORE)
Purpose: Daily farm operations and records

Includes:
- Farms (add, activate, deactivate, lease, sell)
- Crops per farm
- Crop seasons (open / close)
- Crop logs:
  - Activities
  - Inputs
  - Expenses
  - Harvest / outputs
- Reports:
  - Expenses summary
  - Yield
  - Simple profit/loss

Rules:
- Data is private to the farmer
- Reports are derived from logs
- No artificial or manual report data

---

### 5.2 Marketplace
Purpose: Buying, selling, and income generation

Includes:
- Farm produce (crops & livestock)
- Land (sell / lease)
- Labor
- Inputs
- Farm tools
- Paid contact unlock system
- Orders tracking (non-payment)

Rules:
- Listings may be public
- Ownership remains with the creator
- Payments and transactions are not duplicated

---

### 5.3 Logistics & Transport
Purpose: Movement of goods

Includes:
- Transport requests
- Delivery coordination
- Aggregation / pickup points
- Transporter profiles (future phase)

Rules:
- Tied to marketplace and farms
- Start simple, expand later

---

### 5.4 Weather & Climate
Purpose: Decision support

Includes:
- Local weather forecast
- Rain alerts
- Extreme weather warnings
- Basic farming advisories

Rules:
- Read-only for farmers
- Lightweight and simple
- No complex charts by default

---

### 5.5 Market Prices & Trends
Purpose: Price transparency

Includes:
- Daily prices by market/county
- Simple trends (up/down)
- Historical reference

Rules:
- Market-based pricing
- Easy-to-read presentation

---

### 5.6 Knowledge Link
Purpose: Education and guidance

Includes:
- Farming guides
- Reports
- Blog posts
- Best practices

Rules:
- Mostly read-only
- Admin/expert managed
- Low data usage content

---

### 5.7 Tech Corner (Smart Farming)
Purpose: Future innovation

Includes:
- Smart irrigation (placeholder)
- Farm security (placeholder)
- Cold storage technology
- IoT integrations (future)

Rules:
- Educational + future-ready
- No full automation without instruction

---

### 5.8 Chats, Groups & Notifications
Purpose: Communication

Includes:
- Buyer–seller chats
- Farmer groups
- System notifications
- Alerts (weather, logistics, payments)

Rules:
- Contextual messaging
- Avoid spam
- Notifications must be useful

---

### 5.9 Financing & Services
Purpose: Access to support

Includes:
- SACCOs
- Banks
- Insurance (future)
- Extension services (AI/human)

Rules:
- Informational and referral-based
- No financial commitments by default

---

## 6. INNOVATION RULES

Innovation is encouraged but controlled.

For any new feature, AI must:
1. Explain the problem solved
2. Identify the correct module
3. Justify farmer value
4. Respect simplicity and low bandwidth

Allowed:
- Weather alerts
- Smart reminders
- Simple analytics
- Logistics coordination
- AI-assisted insights (basic)

Not allowed:
- Random feature invention
- Enterprise-only complexity
- Core workflow replacement

---

## 7. SECURITY & DATA OWNERSHIP

- Supabase RLS is mandatory
- Users access only their own data
- Never bypass RLS in client code
- Auth, payments, and ownership logic are critical

---

## 8. AI DEVELOPMENT RULES (CURSOR)

- Cursor AI is the primary assistant
- Small, focused edits preferred
- Existing code should be edited, not replaced blindly
- All changes must be explainable to a beginner

Never:
- Rename tables silently
- Modify RLS without instruction
- Invent new schemas unnecessarily

---

## 9. FINAL PRINCIPLE

This platform is built with AI assistance.
Farmer usability, clarity, safety, and maintainability
always come before speed or flashy features.
