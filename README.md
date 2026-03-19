# Rubusoo Quote App

Rubusoo is a Rails SaaS app for export quotation workflows.
It focuses on quote revisions, buyer interaction, public quote links, and multi-format delivery (web, PDF, Excel).

## Core Capabilities

- Internal quote workspace with revision history and decision support
- Public quote page for buyer-facing review
- PDF and Excel export
- Quote template system (branding, visibility toggles, output controls)
- Quote item image support (gallery select + upload, stable per quote item)
- Multi-language UI/content (`en`, `zh-CN`, `es-419`)

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
rails db:prepare
```

Run app:

```powershell
rails server
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

## Tests and Checks

Run minimal checks:

```powershell
bundle exec rails zeitwerk:check
bundle exec rails test
```

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
