# Findrn Website — Frontend v1

A responsive static frontend for the Findrn global services marketplace.

## Included
- Responsive landing page and navigation
- Service category discovery UI
- Search interaction with an honest not-connected state
- Sign-in / sign-up interface preview
- Professional interest form preview
- How it works, feature highlights, FAQ and footer
- Findrn SVG logo and Vercel configuration

## Current scope
This is a frontend-only build. Authentication, provider listings, search, location-aware discovery, booking, messaging, payments and form submission are not connected. No fake providers, reviews, availability or payment confirmations are shown. Forms do not transmit or store personal information.

## Deploy to Vercel
1. Push the contents of this folder to the root of your GitHub repository.
2. In Vercel, choose **Add New → Project** and import the `findrn` repository.
3. Framework Preset: **Other**.
4. Build Command: leave blank. Output Directory: `.`
5. Select **Deploy**.

After deployment, every push to the connected branch triggers a new deployment.

## Local preview
Open `index.html` in a browser. No build step or dependencies are required.
