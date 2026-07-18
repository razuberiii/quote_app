# Route and product-semantics audit

Audit date: 2026-07-18. The canonical product shell is `Inbox / Deals / Library / Settings`.

| Surface | Decision | Reason / destination |
|---|---|---|
| `/` marketing, pricing, demos, auth | KEEP | Public acquisition and account access. |
| `/inbox` | KEEP | Actionable commercial work only. |
| `/deals`, Deal tabs | KEEP | Canonical inquiry-to-close workspace. |
| `/library` | KEEP | Optional reusable products, presets and output knowledge. |
| `/settings/*` | KEEP | Workspace, billing, team and output controls. |
| `/inquiries/new`, review, Build Deal | KEEP | Smart Intake is a Deal entry point, not a permanent module. |
| `/quotes` | REDIRECT | Permanent compatibility redirect to `/deals`. |
| `/quotes/:id/edit` | MIGRATE | Internal Working Draft editor, presented as Quote Studio inside a Deal. |
| `/quotes/:id` | MIGRATE | Publish review only; no lifecycle/status dashboard. |
| `/q/:token` | KEEP | The only canonical public Published Version route. |
| `/customers/*` | DELETE | Removed CRM UI. Buyer records remain contextual Deal data. |
| legacy Quote status, reminders, share and follow-up actions | DELETE | Replaced by stage + one computed Next action + Delivery records. |
| `/public/quote_shares/*`, `/public/quotes/*` | DELETE | Duplicate public quote systems removed. |
| legacy draft PDF/XLSX endpoints | DELETE | Formal output is generated from immutable Published Version snapshots. |
| standalone Proforma Invoice routes | DELETE | PI is one optional Final Document type inside a Deal. |
| onboarding dashboard and action-item generator | DELETE | Progressive setup and Inbox replace generic tasks/checklists. |
| Product routes | MIGRATE | Product detail/edit remain secondary Library context; `/products` redirects to Library. |
| Catalog imports | KEEP | Controlled candidate-review flow; it never auto-populates Library. |
| Admin | MIGRATE | Private operator/audit console only, not a customer product surface. |
| underlying Customer, QuoteShare and ProformaInvoice models | HIDDEN | Retained temporarily for data compatibility; no direct product routes. |

`config/routes.rb` is the executable source of truth. This audit intentionally distinguishes a hidden compatibility model from a supported user workflow.
