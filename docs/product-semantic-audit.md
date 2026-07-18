# Rubusoo product-semantic audit

This inventory is the deletion contract for the Deal-first interface. A route is not retained merely because a controller or model exists.

## Primary product

| Surface | Decision | Product meaning |
| --- | --- | --- |
| `/inbox` | Keep, rewrite | Action queue. One event, one recommended next action. Default after sign-in. |
| `/deals` | Keep, rewrite | All commercial processes grouped by attention, waiting, accepted and closed. |
| `/deals/:id` | Keep, rewrite | Deal control surface: overview, quote, conversation, versions and documents. |
| `/library` | Keep, rewrite | Contextual reusable products, pricing, formats, content and brand resources. |
| `/company_settings/edit` | Keep, rewrite | Workspace and output policy. |
| `/inquiries/new`, `/inquiries/:id` | Keep, rewrite | Smart Intake entry and evidence review; never a primary navigation module. |
| `/quotes/:id/edit` | Keep, rewrite | Quote Studio inside a Deal; legacy model name remains internal. |
| `/q/:token` | Keep, rewrite | Buyer Room for a frozen Published Version. |

## Removed product surfaces

| Surface | Decision | Reason |
| --- | --- | --- |
| `/dashboard` | Delete route, controller, views and JS | Duplicates Inbox and Deals; old CRM metrics and onboarding have no Deal-first meaning. |
| Dashboard KPI, sales signal and quick-start partials | Delete | Display-only zero metrics and account setup tasks do not advance a Deal. |
| Dashboard-specific Stimulus controllers | Delete | Animate a deleted product concept. |
| `/quotes` list | Redirect only | A Quote is not a separate top-level object; users enter through Deals. |
| Customers navigation | Hide | Buyer data remains contextual to a Deal and search. |
| PI navigation | Hide | PI is one optional final-document type inside a Deal. |
| Revisions navigation | Hide | Versions only exist inside a Deal. |

## Contextual secondary surfaces

| Surface | Decision | Context |
| --- | --- | --- |
| Products CRUD | Rewrite | Opened from Library or Quote Studio, not a parallel catalog application. |
| Team and invitations | Rewrite | Settings tab. |
| Account and email verification | Rewrite | Account menu/settings. |
| Quote presets and formats | Merge visually | Library sections, not separate applications. |
| Buyer/customer records | Retain underlying model, remove product prominence | Search and Deal context only. |
| Final documents and PDF/Excel | Keep | Deal Documents, always sourced from frozen Version or Acceptance snapshot. |

## Operational-only surfaces

Admin users, audit logs, billing webhooks and security states remain because they are operational requirements. They do not enter the seller navigation or borrow seller-product semantics.

## Component decisions

- One app shell, navigation and mobile drawer.
- One token system and one control family for button, input, select, upload, tabs, list, dialog and state feedback.
- Document surfaces are explicitly opt-in; ordinary settings and library forms never use white document cards.
- Personal notes widget, old dashboard panels, generic UI card partial and dashboard mobile cards are removed from the seller experience.
- Motion communicates `unstructured → controlled → frozen → accepted`; it is not a carousel or generic fade-in.

## Human-review rule

Automated overflow, accessibility and screenshot comparisons are rejection gates, not design approval. Every generated contact-sheet frame receives a manual Pass/Fail decision before a baseline can be changed.
