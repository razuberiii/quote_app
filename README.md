# Rubusoo Quote App

Rubusoo is a Rails SaaS app for export quotation workflows.
It focuses on quote revisions, buyer interaction, public quote links, and multi-format delivery (web, PDF, Excel).

## Core Capabilities

- Internal quote workspace with revision history and decision support
- Public quote page for buyer-facing review
- PDF and Excel export
- Quote template system (branding, visibility toggles, output controls)
- Quote item image support (gallery select + upload, stable per quote item)
- Chinese-first seller UI with all visible product copy routed through I18n. English and Spanish locale files remain migration sources but are not advertised as complete product locales until their end-to-end audits pass.
- Controlled AI imports for inquiries, product catalogs, and company profiles (strict JSON candidates + human review before write)
- Independent admin console (`/admin`) for user management, impersonation, and audit logs
- Public legal pages for marketing site: `/privacy`, `/terms`

## Tech Stack

- Ruby on Rails `8.1.x`
- PostgreSQL
- Turbo + Stimulus + Importmap
- Active Storage
- Prawn/WickedPDF (PDF), Axlsx (Excel)
- Kamal deploy

## Requirements

- Ruby `3.4.x`
- Node.js + npm (for frontend package deps used by app)
- PostgreSQL `14+` (project currently uses PostgreSQL 16 in deploy config)

## Local Setup (PowerShell)

```powershell
bundle install
npm install
bundle exec rails db:prepare
```

Run app:

```powershell
bundle exec rails server
```

Optional dev process runner:

```powershell
bin\dev
```

## Environment Variables

Common local/prod variables used by this app:

- `RAILS_MASTER_KEY`
- `POSTGRES_PASSWORD` (or `DB_PASSWORD`)
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`
- `APP_HOST`, `RAILS_PROTOCOL`
- `ADMIN_EMAIL`, `ADMIN_PASSWORD`
- `RESEND_API_KEY`, `MAILER_FROM`
- `LANDING_CONTACT_EMAIL`, `LANDING_CONTACT_EMAIL_DEV`
- `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET_KEY`
- `KAMAL_REGISTRY_PASSWORD` (deploy only)

Notes:

- In production, external URL generation should use `APP_HOST`.
- `.kamal/secrets` is env-reference based; do not commit raw secrets.
- Contact form recipient still uses `LANDING_CONTACT_EMAIL` (production) and `LANDING_CONTACT_EMAIL_DEV` (development override).

## Tests and Checks

Run minimal checks:

```powershell
bundle exec rails zeitwerk:check
bundle exec rails test
```

## New-user quote workflow

Rubusoo is quote-first; there is no separate Deal pipeline to maintain.

1. Open **AI import** and add the seller company profile. Confirm the extracted legal identity, contact details and certificates.
2. Open **Document design** once. Choose a curated layout, brand color, content defaults and the customer-page/PDF/Excel languages.
3. Import a catalog or price list into **Library**. AI creates candidates; a user confirms products and reference prices before they become mastered data.
4. Import the customer's inquiry from email text, PDF or spreadsheet. Confirm the customer, products, quantities, destination, Incoterm, price and freight evidence.
5. Edit the quote, preview the customer page, then publish an immutable Version.
6. From **Versions & exports**, open the customer page or download PDF/Excel directly. Send the same Version to the customer.
7. Record customer feedback in **Customer activity**. Apply reviewed changes to a new quote draft and publish V2; V1 remains read-only.

### Suggested AI intake test text

```text
From: Anna Keller <anna@atlas-industrial.example>
Company: Atlas Industrial Supply GmbH, Hamburg, Germany

Please quote 5 × HZ-240 hydraulic power units, 380V / 50Hz, IP54,
including one spare seal kit per unit. Delivery to Hamburg under CIF.
We need shipment before 30 September. Please quote in USD and send the
customer-facing quotation in English.

The inquiry does not include a target price, freight amount or payment term.
Keep those items unconfirmed for our sales team to complete.
```

Expected review behavior: customer, product, quantity, voltage, destination, currency and requested language are extracted with source evidence; price, freight and payment terms remain explicitly unconfirmed instead of being guessed.

## Page Screenshot Script

Manual page capture script:

- Path: `script/capture_pages.ps1`
- Typical command:

```powershell
.\script\capture_pages.ps1 -LoginEmail "you@example.com" -LoginPassword "your_password" -Locale "zh-CN"
```

Behavior notes:

- Script checks `-BaseUrl` reachability before starting.
- When login credentials are provided, script captures only signed-in pages.
- Public pages and admin-only routes are skipped by default.
- Export/download endpoints (PDF/XLSX) are skipped from screenshot output.
- For review convenience, always use `tmp/review_shots/` as the base folder.
- For each capture run, create a new subfolder inside it and keep that run's screenshots there.

Lint/security checks:

```powershell
bundle exec rubocop
bundle exec brakeman --no-pager
bundle exec bundler-audit
bundle exec importmap audit
```

## CI

GitHub Actions workflow: `.github/workflows/ci.yml`

Jobs include:

- Ruby security scan (`brakeman`, `bundler-audit`)
- JS dependency audit (`importmap audit`)
- RuboCop
- Rails tests + system tests (with PostgreSQL service)

Important:

- CI uses `bundle exec ...` commands (not `bin/...`) to avoid cross-platform shebang issues.

## Deploy (Kamal)

Main deploy config: `config/deploy.yml`

Basic flow:

```powershell
bundle exec kamal setup
bundle exec kamal deploy
```

Ensure before deploy:

- `.kamal/secrets` references valid environment variables
- GHCR credentials are valid (`KAMAL_REGISTRY_PASSWORD`)
- target host SSH key/fingerprint is correct
- `APP_HOST` matches your production domain

## Project Notes

- Agent/project execution rules are defined in `AGENTS.md`.
- CSS conventions are in `docs/css-components.md` and should be updated when CSS patterns change.
- For scoped planning/rule-making (UI, feature, stability, performance, refactor), plans must follow `docs/plan-template.md` structure.
- When a cycle is completed, move its plan into `docs/archive/` with a dated filename.
- Admin-only routes are under `/admin/*` and require `role=admin`.
- Suspended users are blocked from login and redirected to `/suspended`.
- Public marketing pages use locale-specific SEO signals:
  - locale canonical URLs (for example `/en`, `/zh-CN`, `/es-419`)
  - `<html lang="...">`
  - `<link rel="alternate" hreflang="...">` (+ `x-default`)
- Production host canonicalization redirects `rubusoo.com` to `www.rubusoo.com` with `301`.

## Asset Troubleshooting (Development)

If you see errors like:

- `The asset 'tailwind.css' was not found in the load path.`
- CSS changes not reflecting even after refresh

check whether development switched to stale precompiled assets.

Quick recovery (PowerShell):

```powershell
# 1) Stop rails server first (Ctrl + C)

# 2) If manifest exists, remove it so dev serves fresh assets
Remove-Item .\public\assets\.manifest.json -Force -ErrorAction SilentlyContinue

# 3) Rebuild tailwind output used by layout/application
bundle exec rails tailwindcss:build

# 4) Restart server
bundle exec rails server -p 3000
```

Then hard refresh browser (`Ctrl + F5`).

Notes:

- `app/views/layouts/application.html.erb` expects `stylesheet_link_tag "tailwind"` and `stylesheet_link_tag "components"`.
- `tailwind.css` should exist at `app/assets/builds/tailwind.css`.
- Running `bundle exec rails assets:precompile` in development can pin digest assets; remove manifest to return to normal dev behavior.
