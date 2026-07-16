# Deal-first module audit

## Kept as primary product surfaces

- **Inbox** — actionable commercial events and one derived Next action.
- **Deals** — the complete inquiry-to-close record.
- **Library** — Products and Quote presets first; Pricing, Content, Formats, Brand and Output settings remain secondary.
- **Settings** — workspace, completion-policy, billing and team controls.
- **Buyer Room** — the recommended interactive delivery surface, not a mandatory channel.

## Merged into Deal context

- Customers became Buyer context and search data.
- Questions, change requests, email/external responses and returned files became Conversation.
- Quote revisions became immutable Versions.
- PDF, Excel, PI and final commercial files became Documents.
- Activity and notifications became Deal timeline plus actionable Inbox signals.
- Catalog and templates became Library.

## Deliberately downgraded

- PI is one optional final-document type after Acceptance.
- Buyer Room viewing is an activity signal only; it is not proof of delivery.
- Follow-up is a Deal date and Next action, not a task-management subsystem.
- Buyer records are created or matched inside intake; users need not maintain CRM first.

## Removed from primary navigation

Home, Quotes, Customers, Catalog, Templates, Activities, Tasks, Files, Revisions, PI, Insights and Reports are not primary modules. Legacy routes required for compatibility may remain reachable from a relevant Deal or Settings context, but no longer define the product architecture.

## Persistence retained but not directly exposed

`Quote`, `Customer`, `QuoteRevision`, `BuyerActivity`, `BuyerQuestion`, `ChangeRequest`, `ProformaInvoice`, `QuoteShare` and notification records remain for migration compatibility and audit history. The current UI presents these through Deal, Conversation, Versions, Delivery, Acceptance and Documents.

