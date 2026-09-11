# MyHome AI

MyHome AI is a Flutter mobile app that helps Malaysian home buyers browse property listings, assess affordability, save favourites, and get AI-assisted buying advice with neighbourhood context from open government data.

## Features

- **Home / Search** — Browse listings from Supabase; keyword search and filters (state, district, price, bedrooms, property type, tenure).
- **Property detail** — View listing details, images, and specs; open AI Advisor from a listing.
- **Neighbourhood insights** — On the detail screen, show area metrics from [data.gov.my](https://api.data.gov.my) (population, crime, water, income, expenditure, schools, hospital beds), with fallback notes when neighbouring-state data is used.
- **Favourites** — Save/unsave listings; search and filter inside your favourites shortlist; login required for per-user saves.
- **Authentication** — Register, login, logout, and forgot-password via Supabase Auth.
- **User profile** — Edit name/phone/state, upload avatar, change password, delete account (with password confirmation and related data cleanup).
- **Financial assessment** — Capture income, savings, debts, and preferences; compute affordability-oriented scores and recommended budget.
- **Debt & asset management** — Manage debts and savings/down-payment related inputs used by the financial profile.
- **Loan calculator** — Estimate mortgage instalments from loan inputs.
- **AI Advisor** — Chat / quick setup, preference extraction, and ranked property recommendations (OpenAI when configured; local rule-based fallback otherwise). AI access is gated until a financial assessment exists.
- **Offline support** — SQLite cache for listings and related data; connectivity awareness and offline banner; pending sync where implemented.
- **Adaptive UI** — Phone bottom navigation and tablet side rail; light/dark theme.

## Tech stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Dart) |
| State management | `provider` |
| Backend | Supabase via `supabase_flutter` |
| Auth | Supabase Auth (sign-up, login, logout, password update/reset) |
| Database | Supabase Postgres (`users`, `properties`, `saved_properties`, `financial_profiles`, `debts`, `property_preferences`, …) |
| Storage | Supabase Storage (`avatars` bucket) |
| AI | OpenAI Chat Completions (`http`, model e.g. `gpt-4o-mini`) |
| Open data | Malaysia Open Data API (`https://api.data.gov.my/data-catalogue`) |
| Local cache | `sqflite`, `path`, `shared_preferences` |
| Other | `intl`, `image_picker`, `connectivity_plus`, Material / `cupertino_icons` |

## Project structure

```
lib/
  main.dart                 # App bootstrap, providers, routes
  constants/                # env.dart.example (copy to env.dart)
  models/                   # Property, recommendation, and related models
  providers/                # Auth, financial, saved, theme, connectivity
  screens/                  # UI screens (home, detail, favourites, auth, AI, …)
  services/                 # Supabase, AI, neighbourhood, cache, etc.
  widgets/                  # Shared UI (nav scaffold, filters, avatar, …)
  utils/                    # Money format, loan math, SQL safety, layout helpers
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (compatible with SDK constraint in `pubspec.yaml`)
- A configured [Supabase](https://supabase.com) project (Auth, tables, Storage)
- Optional: [OpenAI](https://platform.openai.com) API key for live AI responses

## Setup

1. Clone the repository and open the project root.

2. Create local secrets from the example file:

   ```bash
   copy lib\constants\env.dart.example lib\constants\env.dart
   ```

   On macOS/Linux:

   ```bash
   cp lib/constants/env.dart.example lib/constants/env.dart
   ```

3. Edit `lib/constants/env.dart` and set:

   - `supabaseUrl`
   - `supabasePublishableKey`
   - `openAiApiKey` (optional; leave placeholder to use local AI fallbacks)

   **Do not commit `env.dart`** — it is gitignored. Never publish API keys.

4. Install dependencies:

   ```bash
   flutter pub get
   ```

5. Run the app:

   ```bash
   flutter run
   ```

## Supabase expectations

The app expects (at minimum) these resources:

- **Auth** enabled for email/password
- **Tables:** `users`, `properties`, `saved_properties`, `financial_profiles`, `debts`, `property_preferences`
- **Storage bucket:** `avatars` (for profile photos)

Exact schema should match what the services under `lib/services/` read and write.

## Notes

- Listings are stored in Supabase (`properties`); the app does not call a live PropertyGuru search API.
- If OpenAI is unavailable or the key is missing, recommendation/chat flows use local scoring and rule-based text where implemented.
- Neighbourhood insights depend on data.gov.my catalogue coverage; some areas may show `N/A` or marked fallback values.
- Package name in `pubspec.yaml` is `mobile_asg`; product name is **MyHome AI**.

## License / course use

Private assignment project — not published to pub.dev (`publish_to: 'none'`).
