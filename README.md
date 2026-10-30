# Findrn

Findrn is being developed as a global services marketplace connecting customers with service professionals.

## Current experience

The default branch currently contains the static public landing page. It includes service category discovery, a sign-in/sign-up interface preview, a professional interest form preview and responsive layouts. Those forms are not connected to authentication or data storage yet.

The marketplace foundation is being developed on the `feat/marketplace-foundation` branch.

## Repository map

- `index.html` — public landing page, with a first-tab intro and refresh-aware intro behavior
- `findrn-logo.svg` — existing Findrn wordmark
- `favicon.svg` — browser tab icon
- `vercel.json` — static Vercel deployment configuration
- `supabase/migrations/` — database schema, security policies and booking workflows
- `docs/PLATFORM_FOUNDATION.md` — roles, architecture, setup and production checklist

## Roles

- **Customer:** discover, book, message, pay and review.
- **Provider:** apply, get approved, publish services and manage bookings.
- **Admin:** approve providers, moderate listings and manage marketplace operations.

Role changes and provider verification must be performed by trusted server-side/admin workflows. Never allow a browser to grant itself elevated permissions.

## Supabase setup

See [Platform foundation](docs/PLATFORM_FOUNDATION.md) and apply the SQL migration in `supabase/migrations/` through the Supabase SQL Editor.

Never expose the Supabase service-role key in frontend code. Keep secrets in environment variables managed by the deployment platform.

## Deployment

The current public landing page is static and can be deployed on Vercel with Framework Preset **Other**, no build command and the repository root as the output directory. Once the development branch is reviewed and merged, Vercel will deploy the updated default branch if the Git integration is configured.

## Important

The current sign-in, sign-up and provider forms are UI previews. Authentication, live search, provider onboarding, bookings, messaging, payments and notifications are not yet connected. Do not treat this repository as a production-ready marketplace until the integration and security checklist has been completed and tested.
