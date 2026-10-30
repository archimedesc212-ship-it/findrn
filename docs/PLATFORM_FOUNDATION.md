# Findrn platform foundation

This repository is being evolved from a static landing page into a global services marketplace.

## Experience direction

Use the Apple Store India page as a UX reference, not a visual or content template. Borrow the principles that suit a service marketplace:

- A calm, compact navigation bar with clear discovery categories.
- Editorial, large-format feature sections with one clear message and a focused action.
- Horizontal discovery rails and well-spaced category cards instead of dense directories.
- Short benefit sections that explain trust, support and how the marketplace works.
- Consistent typography, whitespace, responsive layouts and restrained transitions.

Keep Findrn's own green identity, F mark, copy and service-marketplace information architecture. Do not copy Apple's logo, product photography, text or branded interface.

The intro should appear on the first visit in a tab, use a short restrained logo reveal, offer Skip, and avoid replaying on a same-tab refresh. A minimal two-note sound is opt-in because browsers generally block sound that starts without a user gesture. The sign-in preview includes email/password, password visibility, confirm password, forgot-password and sign-in/sign-up navigation; it remains non-functional until Supabase Auth is connected.

## Product roles

- **Customer** — discover services, compare approved professionals, request and manage bookings, message the provider, pay through a supported payment processor, and review completed work.
- **Provider** — apply for provider access, wait for admin approval, publish services, manage incoming bookings, communicate with customers, and view payment status.
- **Admin** — review provider applications, moderate categories and listings, inspect bookings and disputes, and manage marketplace operations.

A role is an authorization boundary, not just a different dashboard. Never trust a role sent by the browser. Customer signup creates a customer profile. Provider approval and admin assignment must happen through trusted server-side workflows.

## Current repository state

- `index.html` is the current public static landing page.
- `findrn-logo.svg` is the shared wordmark asset.
- `favicon.svg` is the browser tab icon derived from the existing F mark.
- `supabase/migrations/202610300001_marketplace_core.sql` defines the first database foundation, enums, relationships, indexes, triggers, booking RPCs and row-level security policies.
- The current landing page sign-in, sign-up and professional forms are previews only. They do not submit or store personal information.

## Database model

| Area | Tables |
|---|---|
| Identity | `profiles` |
| Catalogue | `categories`, `services` |
| Provider onboarding | `provider_profiles`, `provider_private_details` |
| Booking | `bookings`, `booking_events` |
| Messaging | `conversations`, `conversation_members`, `messages` |
| Trust | `reviews` |
| Payments | `payment_records` |
| Notifications | `notifications` |

Booking creation automatically creates a conversation and adds the customer and provider as members. Provider responses and cancellation use guarded SQL functions rather than allowing clients to write arbitrary booking states.

## Apply the migration

1. Create or select the Findrn Supabase project.
2. Open **SQL Editor** in the Supabase dashboard.
3. Paste and run the migration file.
4. Confirm the tables and policies appear in the public schema.
5. Test with separate customer, provider and admin test accounts before enabling public onboarding.

Do not put a Supabase service-role key in browser code. The anon/publishable key is intended for the browser only when RLS is correctly enabled.

## Still required before production

- Connect Supabase Auth to the actual sign-in and sign-up UI.
- Add server-side provider application and admin approval workflows.
- Build customer, provider and admin workspaces with real queries and empty/loading/error states.
- Add secure service image storage and upload policies.
- Add location autocomplete/geocoding and distance-aware search.
- Add booking availability, conflict prevention, timezone handling and cancellation rules.
- Integrate a payment processor that supports the launch countries, marketplace payouts and verified webhook signatures. Never mark a payment paid from a browser callback.
- Add email/SMS delivery, notification preferences and abuse controls.
- Add dispute/refund workflows, moderation, audit logs, rate limits, privacy/terms pages and data retention controls.
- Add automated SQL/RLS tests, accessibility checks, browser tests and a real-device deployment check.

## Release rule

Do not show invented providers, reviews, prices, availability, bookings, messages or payment confirmations. If a service is not connected, label it as unavailable or not yet enabled. A successful frontend build is not proof that authentication, database security, payments or marketplace operations work.
